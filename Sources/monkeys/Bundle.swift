import Crypto
import Foundation
import _CryptoExtras

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

let bundleSuffix = ".monsecrets"
private let bundleFormat = "monkeys bundle 1"
private let saltLength = 16

struct ScryptCost {
    let log2Rounds: Int
    let blockSize: Int
    let parallelism: Int

    static let current = ScryptCost(log2Rounds: 17, blockSize: 8, parallelism: 1)

    var headerFields: String { "scrypt \(log2Rounds) \(blockSize) \(parallelism)" }

    var isAffordable: Bool {
        (10...22).contains(log2Rounds) && (1...32).contains(blockSize) && (1...8).contains(parallelism)
    }
}

private func bundleHeader(_ cost: ScryptCost) -> String {
    bundleFormat + " " + cost.headerFields
}

private func costInHeader(_ line: Substring) -> ScryptCost? {
    let words = line.split(separator: " ")
    guard words.count >= 3, words[0...2].joined(separator: " ") == bundleFormat else { return nil }
    let fields = Array(words.dropFirst(3))
    if fields.isEmpty { return .current }
    guard fields.count == 4, fields[0] == "scrypt",
          let log2Rounds = Int(fields[1]), let blockSize = Int(fields[2]), let parallelism = Int(fields[3]) else { return nil }
    let cost = ScryptCost(log2Rounds: log2Rounds, blockSize: blockSize, parallelism: parallelism)
    return cost.isAffordable ? cost : nil
}

struct BundleBlock {
    let profiles: [String]
    let entries: [(name: String, values: [String])]
}

struct ProfileBundle {
    let namespace: String?
    let blocks: [BundleBlock]
}

func bundlePath(_ argument: String) -> String {
    argument.hasSuffix(bundleSuffix) ? argument : argument + bundleSuffix
}

private func readPassphrase(confirming: Bool) throws -> String {
    guard isTerminal(STDIN_FILENO) else {
        let piped = FileHandle.standardInput.readDataToEndOfFile()
        let first = String(decoding: piped, as: UTF8.self).split(separator: "\n", maxSplits: 1).first ?? ""
        guard !first.isEmpty else { throw StoreFailure.bundleFailed("no passphrase on standard input") }
        return String(first)
    }
    guard let entered = getpass("Passphrase: ").map({ String(cString: $0) }), !entered.isEmpty else {
        throw StoreFailure.bundleFailed("no passphrase was given")
    }
    guard confirming else { return entered }
    guard let again = getpass("Again: ").map({ String(cString: $0) }), again == entered else {
        throw StoreFailure.bundleFailed("the passphrases differ")
    }
    return entered
}

private func derivedKey(_ passphrase: String, salt: Data, cost: ScryptCost) throws -> SymmetricKey {
    try KDF.Scrypt.deriveKey(
        from: Data(passphrase.utf8), salt: salt, outputByteCount: 32,
        rounds: 1 << cost.log2Rounds, blockSize: cost.blockSize, parallelism: cost.parallelism
    )
}

private func randomSalt() -> Data {
    Data((0..<saltLength).map { _ in UInt8.random(in: .min ... .max) })
}

private func encodedEntry(_ entry: (name: String, values: [String])) -> String {
    let encoded = entry.values.map { Data($0.utf8).base64EncodedString() }
    return entry.name + "=" + encoded.joined(separator: ",")
}

private func serializedBlock(_ block: BundleBlock, in namespace: String?) -> [String] {
    let written = block.profiles.map { shortened($0, in: namespace) }
    return ["@" + written.joined(separator: ",")] + block.entries.map(encodedEntry)
}

private func serialized(_ bundle: ProfileBundle) -> Data {
    let header = bundle.namespace.map { ["+" + $0] } ?? []
    let lines = header + bundle.blocks.flatMap { serializedBlock($0, in: bundle.namespace) }
    return Data(lines.joined(separator: "\n").utf8)
}

private func deserialized(_ plaintext: Data) throws -> ProfileBundle {
    var namespace: String?
    var blocks: [BundleBlock] = []
    for line in String(decoding: plaintext, as: UTF8.self).split(separator: "\n") {
        if line.hasPrefix("+") {
            let name = String(line.dropFirst())
            guard namespace == nil, blocks.isEmpty, isValidProfileName(name) else {
                throw StoreFailure.bundleFailed("the bundle's +namespace line is not first, or not a name")
            }
            namespace = name
            continue
        }
        if line.hasPrefix("@") {
            let profiles = line.dropFirst().split(separator: ",").map(String.init)
            guard !profiles.isEmpty, profiles.allSatisfy(isValidProfileName) else {
                throw StoreFailure.bundleFailed("the bundle carries no profile")
            }
            blocks.append(BundleBlock(profiles: profiles.map { prefixed($0, with: namespace) }, entries: []))
            continue
        }
        let parts = line.split(separator: "=", maxSplits: 1)
        guard let current = blocks.popLast(), parts.count == 2, isValidKey(String(parts[0])) else {
            throw StoreFailure.bundleFailed("a line in the bundle is not KEY=secret")
        }
        let encoded = parts[1].split(separator: ",", omittingEmptySubsequences: false)
        let decoded = encoded.compactMap { Data(base64Encoded: String($0)) }
        guard decoded.count == encoded.count, decoded.count == current.profiles.count else {
            throw StoreFailure.bundleFailed("a line in the bundle is not KEY=secret")
        }
        let entry = (String(parts[0]), decoded.map { String(decoding: $0, as: UTF8.self) })
        blocks.append(BundleBlock(profiles: current.profiles, entries: current.entries + [entry]))
    }
    guard !blocks.isEmpty else { throw StoreFailure.bundleFailed("the bundle carries no profile") }
    return ProfileBundle(namespace: namespace, blocks: blocks)
}

func writeBundle(_ bundle: ProfileBundle, to path: String) throws {
    let passphrase = try readPassphrase(confirming: true)
    let salt = randomSalt()
    let cost = ScryptCost.current
    let sealed = try ChaChaPoly.seal(serialized(bundle), using: try derivedKey(passphrase, salt: salt, cost: cost))
    let body = (salt + sealed.combined).base64EncodedString()
    let contents = bundleHeader(cost) + "\n" + body + "\n"
    guard FileManager.default.createFile(atPath: path, contents: Data(contents.utf8), attributes: [.posixPermissions: 0o600]) else {
        throw StoreFailure.bundleFailed("cannot write \(path)")
    }
}

func readBundle(from path: String) throws -> ProfileBundle {
    guard let contents = FileManager.default.contents(atPath: path) else {
        throw StoreFailure.bundleFailed("cannot read \(path)")
    }
    let lines = String(decoding: contents, as: UTF8.self).split(separator: "\n")
    guard lines.count == 2, let cost = costInHeader(lines[0]), let raw = Data(base64Encoded: String(lines[1])),
          raw.count > saltLength else {
        throw StoreFailure.bundleFailed("\(path) is not a monkeys bundle")
    }
    let passphrase = try readPassphrase(confirming: false)
    let key = try derivedKey(passphrase, salt: raw.prefix(saltLength), cost: cost)
    do {
        let sealed = try ChaChaPoly.SealedBox(combined: raw.dropFirst(saltLength))
        return try deserialized(try ChaChaPoly.open(sealed, using: key))
    } catch is CryptoKitError {
        throw StoreFailure.bundleFailed("wrong passphrase, or \(path) is damaged")
    }
}

func blockText(_ blocks: [Block], in namespace: String?) -> String {
    blocks.map { block in
        let written = block.profiles.map { shortened($0, in: namespace) }
        return (["@" + written.joined(separator: ",")] + block.keys).joined(separator: "\n")
    }.joined(separator: "\n") + "\n"
}

func projectFileContents(namespace: String?, _ blocks: [Block]) -> String {
    let header = namespace.map { "+" + $0 + "\n" } ?? ""
    return header + blockText(blocks, in: namespace)
}
