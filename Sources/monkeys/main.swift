import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

func printToStandardError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func isTerminal(_ descriptor: Int32) -> Bool {
    isatty(descriptor) != 0
}

func printHintToTerminal(_ message: String) {
    guard isTerminal(STDERR_FILENO) else { return }
    printToStandardError(message)
}

func isSetInThisEnvironment(_ name: String) -> Bool {
    ProcessInfo.processInfo.environment[name] != nil
}

func askYesOrNo(_ question: String) -> Bool {
    guard isTerminal(STDIN_FILENO), isTerminal(STDERR_FILENO) else { return false }
    FileHandle.standardError.write(Data((question + " " + messageStyle("[y/N]", .bold) + " ").utf8))
    guard let answer = readLine(strippingNewline: true)?.lowercased() else { return false }
    return answer == "y" || answer == "yes"
}

func readSecretFromInput() -> String {
    if !isTerminal(STDIN_FILENO) {
        let piped = FileHandle.standardInput.readDataToEndOfFile()
        return String(decoding: piped, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard let entered = getpass("Secret: ") else { return "" }
    return String(cString: entered)
}

func requireKey(_ arguments: [String]) throws -> String {
    guard let name = arguments.first else { throw StoreFailure.invalidKey("") }
    guard isValidKey(name) else { throw StoreFailure.invalidKey(name) }
    return name
}

func spendHint(_ scope: Scope, _ name: String) -> String {
    if let keys = scope.projectKeys, keys.contains(name) { return "monkeys run <command>" }
    return "monkeys run \(scope.profileArgument)\(name) <command>"
}

func runSet(_ arguments: [String]) throws {
    let (scope, rest) = try resolveScope(arguments)
    let name = try requireKey(rest)
    let value = readSecretFromInput()
    guard !value.isEmpty else { throw StoreFailure.emptySecret }
    try secretStore.store(value, forName: scope.storedName(name))
    printToStandardError(messageStyle("stored", .good) + " " + messageStyle(scope.storedName(name), .bold))
    printHintToTerminal(messageStyle("give it to a command with:", .dim))
    printHintToTerminal("  " + messageStyle(spendHint(scope, name), .argument))
}

func runRemove(_ arguments: [String]) throws {
    let (scope, rest) = try resolveScope(arguments)
    let name = try requireKey(rest)
    try secretStore.remove(forName: scope.storedName(name))
    printToStandardError(messageStyle("removed", .good) + " " + messageStyle(scope.storedName(name), .bold))
    guard isSetInThisEnvironment(name) else { return }
    printHintToTerminal(messageStyle("this shell still carries it; clear it with:", .dim))
    printHintToTerminal("  " + messageStyle("unset \(name)", .argument))
}

func runList() throws {
    for name in try secretStore.storedKeys() { print(name) }
}

func validatedKeys(_ scope: Scope, _ rest: [String]) throws -> [String] {
    let keys = rest.isEmpty ? try keysInScope(scope) : rest
    for name in keys where !isValidKey(name) { throw StoreFailure.invalidKey(name) }
    return keys
}

func runPreview(_ arguments: [String]) throws {
    let (scope, rest) = try resolveScope(arguments)
    let keys = try validatedKeys(scope, rest)
    guard let width = keys.map(\.count).max() else { return }
    for name in keys {
        let masked = maskedValue(try secretStore.read(forName: scope.storedName(name)))
        print(name.padding(toLength: width, withPad: " ", startingAt: 0) + "  " + masked)
    }
}

private let packForm = "monkeys pack [@profile] [name] [--only @a,b KEY,KEY @c ...]"

private let profileNeeded = "a bundle carries a profile: run this in a project with a \(projectFileName) file, or name one with @profile"

private func keysIn(_ token: String) throws -> [String] {
    let keys = token.split(separator: ",").map(String.init)
    guard !keys.isEmpty, keys.allSatisfy(isValidKey) else { throw StoreFailure.badInvocation(packForm) }
    return keys
}

private func resolvedProfiles(_ argument: String, in project: Project?) throws -> [String] {
    let pieces = argument.dropFirst().split(separator: ",").map { $0.hasPrefix("@") ? String($0.dropFirst()) : String($0) }
    guard !pieces.isEmpty, pieces.allSatisfy({ !$0.isEmpty }) else { throw StoreFailure.badInvocation(packForm) }
    return try pieces.map { name in
        guard let project else {
            guard isValidProfileName(name) else { throw StoreFailure.invalidProfileName("@" + name) }
            return name
        }
        return try project.profile(matching: name)
    }
}

private func coalesced(_ blocks: [Block]) -> [Block] {
    blocks.reduce(into: []) { result, block in
        if let last = result.last, last.profiles == block.profiles {
            result[result.count - 1] = Block(profiles: last.profiles, keys: last.keys + block.keys)
        } else {
            result.append(block)
        }
    }
}

private func restricted(_ blocks: [Block], toProfiles profiles: [String]) -> [Block] {
    coalesced(blocks.compactMap { block in
        let kept = block.profiles.filter(profiles.contains)
        return kept.isEmpty ? nil : Block(profiles: kept, keys: block.keys)
    })
}

private func restricted(_ blocks: [Block], toNames keys: [String]) -> [Block] {
    blocks.compactMap { block in
        let kept = block.keys.filter(keys.contains)
        return kept.isEmpty ? nil : Block(profiles: block.profiles, keys: kept)
    }
}

private func storedBlocks(for profiles: [String]) throws -> [Block] {
    try profiles.map { Block(profiles: [$0], keys: try keysInScope(Scope(profile: $0, project: nil))) }
}

private func selectedBlocks(_ tokens: [String], from written: [Block], defaultingTo scope: [String], project: Project?) throws -> [Block] {
    var blocks: [Block] = []
    var open: [String]?
    var openNames: [String] = []
    var leading: [String] = []
    func closeOpen() throws {
        guard let profiles = open else { return }
        if !openNames.isEmpty {
            blocks.append(Block(profiles: profiles, keys: openNames))
        } else if project == nil {
            blocks += try storedBlocks(for: profiles)
        } else {
            blocks += restricted(written, toProfiles: profiles)
        }
        open = nil
        openNames = []
    }
    for token in tokens {
        if token.hasPrefix("@") {
            try closeOpen()
            open = try resolvedProfiles(token, in: project)
            continue
        }
        let keys = try keysIn(token)
        guard open != nil else {
            guard blocks.isEmpty else { throw StoreFailure.badInvocation(packForm) }
            leading += keys
            continue
        }
        openNames += keys
    }
    try closeOpen()
    guard leading.isEmpty || blocks.isEmpty else { throw StoreFailure.badInvocation(packForm) }
    guard !leading.isEmpty else { return blocks.isEmpty ? written : blocks }
    let base = restricted(written, toProfiles: scope)
    for name in leading where !base.contains(where: { $0.keys.contains(name) }) {
        throw StoreFailure.bundleFailed("\(name) is not listed for @\(scope.joined(separator: ",")), so there is nothing to pack under that key")
    }
    return restricted(base, toNames: leading)
}

private func packedBlocks(_ arguments: [String]) throws -> (blocks: [Block], project: Project?, fileName: String?) {
    let (chosen, afterProfile) = try takeProfileArgument(arguments)
    let project = try locateProject()
    var rest = afterProfile
    var selection: [String] = []
    if let flag = rest.firstIndex(of: "--only") {
        selection = Array(rest[(flag + 1)...])
        rest.removeSubrange(flag...)
    }
    guard rest.count <= 1 else { throw StoreFailure.badInvocation(packForm) }
    switch chosen {
    case .global:
        throw StoreFailure.bundleFailed(profileNeeded)
    case .named(let name):
        guard !selection.contains(where: { $0.hasPrefix("@") }) else { throw StoreFailure.badInvocation(packForm) }
        let profiles = try resolvedProfiles("@" + name, in: project)
        let written = try project.map { restricted($0.blocks, toProfiles: profiles) } ?? storedBlocks(for: profiles)
        return (try selectedBlocks(selection, from: written, defaultingTo: profiles, project: project), project, rest.first)
    case .none:
        guard let project else {
            guard selection.contains(where: { $0.hasPrefix("@") }) else { throw StoreFailure.bundleFailed(profileNeeded) }
            return (try selectedBlocks(selection, from: [], defaultingTo: [], project: nil), nil, rest.first)
        }
        return (try selectedBlocks(selection, from: project.blocks, defaultingTo: [project.defaultProfile], project: project), project, rest.first)
    }
}

private func filledBlock(_ block: Block, project: Project?) throws -> BundleBlock {
    if let project {
        for profile in block.profiles {
            let listed = project.keys(for: profile)
            if let stray = block.keys.first(where: { !listed.contains($0) }) {
                throw StoreFailure.bundleFailed("\(stray) is not listed for @\(profile), so there is nothing to pack under that key")
            }
        }
    }
    var entries: [(name: String, values: [String])] = []
    var missing: [String: [String]] = [:]
    for name in block.keys {
        var values: [String] = []
        for profile in block.profiles {
            do {
                values.append(try secretStore.read(forName: profile + "/" + name))
            } catch StoreFailure.keyNotStored {
                missing[profile, default: []].append(name)
            }
        }
        entries.append((name, values))
    }
    if let profile = block.profiles.first(where: { missing[$0] != nil }) {
        throw StoreFailure.keysNotStored(missing[profile]!, "@" + profile)
    }
    return BundleBlock(profiles: block.profiles, entries: entries)
}

private func blockLines(_ profiles: [[String]]) -> String {
    profiles.map { "@" + $0.joined(separator: ",") }.joined(separator: " ")
}

func runPack(_ arguments: [String]) throws {
    let (blocks, project, fileName) = try packedBlocks(arguments)
    guard !blocks.isEmpty else { throw StoreFailure.bundleFailed("nothing to pack: no keys are listed for that") }
    let filled = try blocks.map { try filledBlock($0, project: project) }
    let path = bundlePath(fileName ?? filled[0].profiles[0])
    try writeBundle(ProfileBundle(blocks: filled), to: path)
    let count = filled.reduce(0) { $0 + $1.entries.count * $1.profiles.count }
    printToStandardError(messageStyle("wrote", .good) + " " + messageStyle(path, .bold) + ": \(blockLines(filled.map(\.profiles))), \(count) secret\(count == 1 ? "" : "s")")
}

func gitRoot(above directory: String) -> String? {
    var directory = directory
    while true {
        if FileManager.default.fileExists(atPath: directory + "/.git") { return directory }
        guard directory != "/" else { return nil }
        directory = URL(fileURLWithPath: directory).deletingLastPathComponent().path
    }
}

func unpackDestination(_ given: String?) throws -> String {
    let current = FileManager.default.currentDirectoryPath
    guard let given else { return gitRoot(above: current) ?? current }
    let directory = URL(fileURLWithPath: given).standardizedFileURL.path
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw StoreFailure.bundleFailed("\(given) is not a directory")
    }
    return directory
}

func reconcileProjectFile(_ blocks: [Block], in directory: String) throws {
    let path = directory + "/" + projectFileName
    let shown = directory == FileManager.default.currentDirectoryPath ? projectFileName : abbreviatingHome(path)
    func counted(_ blocks: [Block]) -> String {
        let total = blocks.reduce(0) { $0 + $1.keys.count }
        return "\(total) key\(total == 1 ? "" : "s")"
    }
    guard FileManager.default.fileExists(atPath: path) else {
        try projectFileContents(blocks).write(toFile: path, atomically: true, encoding: .utf8)
        printToStandardError(messageStyle("wrote", .good) + " " + messageStyle(shown, .bold) + ": \(blockLines(blocks.map(\.profiles))), \(counted(blocks))")
        return
    }
    let existing = try parseProject(at: path, directory: directory)
    var additions: [Block] = []
    for block in blocks {
        var order: [[String]] = []
        var profilesMissing: [[String]: [String]] = [:]
        for profile in block.profiles {
            let listed = existing.keys(for: profile)
            let missing = block.keys.filter { !listed.contains($0) }
            guard !missing.isEmpty else { continue }
            if profilesMissing[missing] == nil { order.append(missing) }
            profilesMissing[missing, default: []].append(profile)
        }
        additions += order.map { Block(profiles: profilesMissing[$0]!, keys: $0) }
    }
    guard !additions.isEmpty else {
        printToStandardError("\(shown) already lists these keys")
        return
    }
    let current = try String(contentsOfFile: path, encoding: .utf8)
    let separator = current.hasSuffix("\n") ? "" : "\n"
    try (current + separator + projectFileContents(additions)).write(toFile: path, atomically: true, encoding: .utf8)
    printToStandardError(messageStyle("added", .good) + " " + messageStyle(blockLines(additions.map(\.profiles)), .bold) + " with \(counted(additions)) to \(shown)")
}


private func mark(_ isStored: Bool) -> String {
    isStored ? outputStyle("✓", .good) : outputStyle("✗", .bad)
}

func runDoctor(_ arguments: [String]) throws {
    let isShort = arguments == ["--short"]
    guard arguments.isEmpty || isShort else { throw StoreFailure.badInvocation("monkeys doctor [--short]") }
    guard let project = try locateProject() else {
        throw StoreFailure.badInvocation("monkeys doctor next to a \(projectFileName) file")
    }
    let stored = Set(try secretStore.storedKeys())
    var isComplete = true
    for profile in project.profiles {
        let keys = project.keys(for: profile)
        let missing = keys.filter { !stored.contains(profile + "/" + $0) }
        isComplete = isComplete && missing.isEmpty
        if isShort {
            if !missing.isEmpty { print("missing @\(profile): " + missing.joined(separator: ",")) }
            continue
        }
        let label = profile == project.defaultProfile ? outputStyle("  default", .dim) : ""
        print(outputStyle("@" + profile, .bold) + label)
        for name in keys { print("  " + mark(!missing.contains(name)) + " " + name) }
    }
    guard isComplete else { exit(1) }
}

func runUnpack(_ arguments: [String]) throws {
    let keepsBundle = arguments.contains("--keep")
    let positional = arguments.filter { $0 != "--keep" }
    guard let name = positional.first, positional.count <= 2 else {
        throw StoreFailure.badInvocation("monkeys unpack <name> [directory] [--keep]")
    }
    let destination = try unpackDestination(positional.dropFirst().first)
    let path = bundlePath(name)
    let bundle = try readBundle(from: path)
    try reconcileProjectFile(bundle.blocks.map { Block(profiles: $0.profiles, keys: $0.entries.map(\.name)) }, in: destination)
    for block in bundle.blocks {
        var stored: [String] = []
        for entry in block.entries {
            for (profile, value) in zip(block.profiles, entry.values) {
                try secretStore.store(value, forName: profile + "/" + entry.name)
                stored.append(profile + "/" + entry.name)
            }
        }
        printToStandardError(messageStyle("stored", .good) + " " + stored.map { messageStyle($0, .bold) }.joined(separator: ", "))
    }
    guard !keepsBundle else { return }
    guard unlink(path) == 0 else {
        printToStandardError(messageStyle("kept", .bad) + " \(abbreviatingHome(path)): \(String(cString: strerror(errno)))")
        return
    }
    printToStandardError(messageStyle("removed", .good) + " " + messageStyle(abbreviatingHome(path), .bold))
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    print(usage)
    exit(0)
}
let rest = Array(arguments.dropFirst())

do {
    switch command {
    case "set": try runSet(rest)
    case "list": try runList()
    case "preview": try runPreview(rest)
    case "remove": try runRemove(rest)
    case "pack": try runPack(rest)
    case "run": try runCommandWithSecrets(rest)
    case "unpack": try runUnpack(rest)
    case "export": try runExport(rest)
    case "doctor": try runDoctor(rest)
    case "fill": try runFill(rest)
    case "help", "-h", "--help": print(usage)
    default:
        printToStandardError(messageStyle("unknown command:", .bad) + " \(command)")
        printToStandardError("run " + messageStyle("monkeys help", .argument) + " for the commands")
        exit(2)
    }
} catch let failure as StoreFailure {
    printToStandardError(messageStyle("monkeys:", .bad) + " \(failure)")
    exit(1)
} catch {
    printToStandardError(messageStyle("monkeys:", .bad) + " \(error)")
    exit(1)
}
