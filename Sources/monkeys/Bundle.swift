import Crypto
import Foundation
import _CryptoExtras

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

let bundleSuffix = ".monkeys"
private let bundleHeader = "monkeys bundle 1"
private let saltLength = 16
private let scryptRounds = 1 << 17
private let scryptBlockSize = 8
private let scryptParallelism = 1

struct BundleBlock {
    let profiles: [String]
    let entries: [(name: String, values: [String])]
}

struct ProfileBundle {
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

private func derivedKey(_ passphrase: String, salt: Data) throws -> SymmetricKey {
    try KDF.Scrypt.deriveKey(
        from: Data(passphrase.utf8), salt: salt, outputByteCount: 32,
        rounds: scryptRounds, blockSize: scryptBlockSize, parallelism: scryptParallelism
    )
}

private func randomSalt() -> Data {
    Data((0..<saltLength).map { _ in UInt8.random(in: .min ... .max) })
}

private func serialized(_ bundle: ProfileBundle) -> Data {
    let lines = bundle.blocks.flatMap { block in
        ["@" + block.profiles.joined(separator: ",")] + block.entries.map { entry in
            entry.name + "=" + entry.values.map { Data($0.utf8).base64EncodedString() }.joined(separator: ",")
        }
    }
    return Data(lines.joined(separator: "\n").utf8)
}

private func deserialized(_ plaintext: Data) throws -> ProfileBundle {
    var blocks: [BundleBlock] = []
    for line in String(decoding: plaintext, as: UTF8.self).split(separator: "\n") {
        if line.hasPrefix("@") {
            let profiles = line.dropFirst().split(separator: ",").map(String.init)
            guard !profiles.isEmpty, profiles.allSatisfy(isValidProfileName) else {
                throw StoreFailure.bundleFailed("the bundle names no profile")
            }
            blocks.append(BundleBlock(profiles: profiles, entries: []))
            continue
        }
        let parts = line.split(separator: "=", maxSplits: 1)
        guard let current = blocks.popLast(), parts.count == 2, isValidVariableName(String(parts[0])) else {
            throw StoreFailure.bundleFailed("a line in the bundle is not NAME=value")
        }
        let encoded = parts[1].split(separator: ",", omittingEmptySubsequences: false)
        let decoded = encoded.compactMap { Data(base64Encoded: String($0)) }
        guard decoded.count == encoded.count, decoded.count == current.profiles.count else {
            throw StoreFailure.bundleFailed("a line in the bundle is not NAME=value")
        }
        let entry = (String(parts[0]), decoded.map { String(decoding: $0, as: UTF8.self) })
        blocks.append(BundleBlock(profiles: current.profiles, entries: current.entries + [entry]))
    }
    guard !blocks.isEmpty else { throw StoreFailure.bundleFailed("the bundle names no profile") }
    return ProfileBundle(blocks: blocks)
}

func writeBundle(_ bundle: ProfileBundle, to path: String) throws {
    let passphrase = try readPassphrase(confirming: true)
    let salt = randomSalt()
    let sealed = try ChaChaPoly.seal(serialized(bundle), using: try derivedKey(passphrase, salt: salt))
    let body = (salt + sealed.combined).base64EncodedString()
    let contents = bundleHeader + "\n" + body + "\n"
    guard FileManager.default.createFile(atPath: path, contents: Data(contents.utf8), attributes: [.posixPermissions: 0o600]) else {
        throw StoreFailure.bundleFailed("cannot write \(path)")
    }
}

func readBundle(from path: String) throws -> ProfileBundle {
    guard let contents = FileManager.default.contents(atPath: path) else {
        throw StoreFailure.bundleFailed("cannot read \(path)")
    }
    let lines = String(decoding: contents, as: UTF8.self).split(separator: "\n")
    guard lines.count == 2, lines[0] == bundleHeader, let raw = Data(base64Encoded: String(lines[1])),
          raw.count > saltLength else {
        throw StoreFailure.bundleFailed("\(path) is not a monkeys bundle")
    }
    let passphrase = try readPassphrase(confirming: false)
    let key = try derivedKey(passphrase, salt: raw.prefix(saltLength))
    do {
        let sealed = try ChaChaPoly.SealedBox(combined: raw.dropFirst(saltLength))
        return try deserialized(try ChaChaPoly.open(sealed, using: key))
    } catch is CryptoKitError {
        throw StoreFailure.bundleFailed("wrong passphrase, or \(path) is damaged")
    }
}

func projectFileContents(_ blocks: [Block]) -> String {
    blocks.map { block in
        (["@" + block.profiles.joined(separator: ",")] + block.names).joined(separator: "\n")
    }.joined(separator: "\n") + "\n"
}
