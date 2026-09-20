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

func readValueFromInput() -> String {
    if !isTerminal(STDIN_FILENO) {
        let piped = FileHandle.standardInput.readDataToEndOfFile()
        return String(decoding: piped, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard let entered = getpass("Value: ") else { return "" }
    return String(cString: entered)
}

func requireName(_ arguments: [String]) throws -> String {
    guard let name = arguments.first else { throw StoreFailure.invalidVariableName("") }
    guard isValidVariableName(name) else { throw StoreFailure.invalidVariableName(name) }
    return name
}

func spendHint(_ scope: Scope, _ name: String) -> String {
    if let names = scope.projectNames, names.contains(name) { return "monkeys run <command>" }
    return "monkeys run \(scope.profileArgument)\(name) <command>"
}

func runSet(_ arguments: [String]) throws {
    let (scope, rest) = try resolveScope(arguments)
    let name = try requireName(rest)
    let value = readValueFromInput()
    guard !value.isEmpty else { throw StoreFailure.emptyValue }
    try secretStore.store(value, forName: scope.storedName(name))
    printToStandardError(messageStyle("stored", .good) + " " + messageStyle(scope.storedName(name), .bold))
    printHintToTerminal(messageStyle("give it to a command with:", .dim))
    printHintToTerminal("  " + messageStyle(spendHint(scope, name), .argument))
}

func runRemove(_ arguments: [String]) throws {
    let (scope, rest) = try resolveScope(arguments)
    let name = try requireName(rest)
    try secretStore.remove(forName: scope.storedName(name))
    printToStandardError(messageStyle("removed", .good) + " " + messageStyle(scope.storedName(name), .bold))
    guard isSetInThisEnvironment(name) else { return }
    printHintToTerminal(messageStyle("this shell still carries it; clear it with:", .dim))
    printHintToTerminal("  " + messageStyle("unset \(name)", .argument))
}

func runList() throws {
    for name in try secretStore.storedNames() { print(name) }
}

func validatedNames(_ scope: Scope, _ rest: [String]) throws -> [String] {
    let names = rest.isEmpty ? try namesInScope(scope) : rest
    for name in names where !isValidVariableName(name) { throw StoreFailure.invalidVariableName(name) }
    return names
}

func runPreview(_ arguments: [String]) throws {
    let (scope, rest) = try resolveScope(arguments)
    let names = try validatedNames(scope, rest)
    guard let width = names.map(\.count).max() else { return }
    for name in names {
        let masked = maskedValue(try secretStore.read(forName: scope.storedName(name)))
        print(name.padding(toLength: width, withPad: " ", startingAt: 0) + "  " + masked)
    }
}

private let packForm = "monkeys pack [@profile] [name] [--only @a NAME,NAME @b ...]"

private struct PackBlock {
    let profile: String
    let names: [String]?
}

private let profileNeeded = "a bundle carries a profile: run this in a project with a \(projectFileName) file, or name one with @profile"

private func namesIn(_ token: String) throws -> [String] {
    let names = token.split(separator: ",").map(String.init)
    guard !names.isEmpty, names.allSatisfy(isValidVariableName) else { throw StoreFailure.badInvocation(packForm) }
    return names
}

private func resolvedProfile(_ argument: String, in project: Project?) throws -> String {
    guard argument.count > 1 else { throw StoreFailure.badInvocation(packForm) }
    let name = String(argument.dropFirst())
    guard let project else {
        guard isValidProfileName(name) else { throw StoreFailure.invalidProfileName(argument) }
        return name
    }
    return try project.profile(matching: name)
}

private func selectedBlocks(_ tokens: [String], defaults: [String], project: Project?) throws -> [PackBlock] {
    var blocks: [PackBlock] = []
    var leading: [String] = []
    for token in tokens {
        if token.hasPrefix("@") {
            blocks.append(PackBlock(profile: try resolvedProfile(token, in: project), names: nil))
            continue
        }
        let names = try namesIn(token)
        guard let last = blocks.popLast() else {
            leading += names
            continue
        }
        blocks.append(PackBlock(profile: last.profile, names: (last.names ?? []) + names))
    }
    guard blocks.isEmpty || leading.isEmpty else { throw StoreFailure.badInvocation(packForm) }
    guard blocks.isEmpty else { return blocks }
    return defaults.map { PackBlock(profile: $0, names: leading.isEmpty ? nil : leading) }
}

private func packedBlocks(_ arguments: [String]) throws -> (blocks: [PackBlock], project: Project?, fileName: String?) {
    let (chosen, afterProfile) = try takeProfileArgument(arguments)
    let project = try locateProject()
    var rest = afterProfile
    var selection: [String] = []
    if let flag = rest.firstIndex(of: "--only") {
        selection = Array(rest[(flag + 1)...])
        rest.removeSubrange(flag...)
    }
    guard rest.count <= 1 else { throw StoreFailure.badInvocation(packForm) }
    let defaults: [String]
    switch chosen {
    case .personal:
        throw StoreFailure.bundleFailed(profileNeeded)
    case .named(let name):
        guard !selection.contains(where: { $0.hasPrefix("@") }) else { throw StoreFailure.badInvocation(packForm) }
        defaults = [try resolvedProfile("@" + name, in: project)]
    case .none:
        guard let project else {
            guard selection.contains(where: { $0.hasPrefix("@") }) else { throw StoreFailure.bundleFailed(profileNeeded) }
            defaults = []
            return (try selectedBlocks(selection, defaults: defaults, project: nil), nil, rest.first)
        }
        defaults = project.profiles
    }
    return (try selectedBlocks(selection, defaults: defaults, project: project), project, rest.first)
}

private func collectedValues(_ scope: Scope, keeping only: [String]?) throws -> ProfileValues {
    let listed = try namesInScope(scope)
    if let only, let stray = only.first(where: { !listed.contains($0) }) {
        throw StoreFailure.bundleFailed("\(stray) is not listed for @\(scope.profile ?? ""), so there is nothing to pack under that name")
    }
    var values: [(name: String, value: String)] = []
    var missing: [String] = []
    for name in listed where only?.contains(name) ?? true {
        do {
            values.append((name, try secretStore.read(forName: scope.storedName(name))))
        } catch StoreFailure.nameNotStored {
            missing.append(name)
        }
    }
    guard missing.isEmpty else { throw StoreFailure.namesNotStored(missing, scope.profileArgument) }
    return ProfileValues(profile: scope.profile ?? "", values: values)
}

func runPack(_ arguments: [String]) throws {
    let (blocks, project, fileName) = try packedBlocks(arguments)
    let filled = try blocks.map { try collectedValues(Scope(profile: $0.profile, project: project), keeping: $0.names) }
    let path = bundlePath(fileName ?? filled[0].profile)
    try writeBundle(ProfileBundle(profiles: filled), to: path)
    let count = filled.reduce(0) { $0 + $1.values.count }
    let listed = filled.map { "@" + $0.profile }.joined(separator: ", ")
    printToStandardError(messageStyle("wrote", .good) + " " + messageStyle(path, .bold) + ": \(listed), \(count) value\(count == 1 ? "" : "s")")
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

func reconcileProjectFile(profile: String, names: [String], in directory: String) throws {
    let path = directory + "/" + projectFileName
    let shown = directory == FileManager.default.currentDirectoryPath ? projectFileName : abbreviatingHome(path)
    let counted = "\(names.count) name\(names.count == 1 ? "" : "s")"
    guard FileManager.default.fileExists(atPath: path) else {
        try projectFileContents(profile: profile, names: names).write(toFile: path, atomically: true, encoding: .utf8)
        printToStandardError(messageStyle("wrote", .good) + " " + messageStyle(shown, .bold) + ": @\(profile), \(counted)")
        return
    }
    let existing = try parseProject(at: path, directory: directory)
    let listed = existing.names(for: profile)
    let missing = names.filter { !listed.contains($0) }
    guard !missing.isEmpty else {
        printToStandardError("\(shown) already lists these names under @\(profile)")
        return
    }
    let current = try String(contentsOfFile: path, encoding: .utf8)
    let separator = current.hasSuffix("\n") ? "" : "\n"
    try (current + separator + projectFileContents(profile: profile, names: missing)).write(toFile: path, atomically: true, encoding: .utf8)
    let added = "\(missing.count) name\(missing.count == 1 ? "" : "s")"
    printToStandardError(messageStyle("added", .good) + " " + messageStyle("@\(profile)", .bold) + " with \(added) to \(shown)")
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
    let stored = Set(try secretStore.storedNames())
    var isComplete = true
    for profile in project.profiles {
        let names = project.names(for: profile)
        let missing = names.filter { !stored.contains(profile + "/" + $0) }
        isComplete = isComplete && missing.isEmpty
        if isShort {
            if !missing.isEmpty { print("missing @\(profile): " + missing.joined(separator: ",")) }
            continue
        }
        let label = profile == project.defaultProfile ? outputStyle("  default", .dim) : ""
        print(outputStyle("@" + profile, .bold) + label)
        for name in names { print("  " + mark(!missing.contains(name)) + " " + name) }
    }
    guard isComplete else { exit(1) }
}

func runUnpack(_ arguments: [String]) throws {
    guard let name = arguments.first, arguments.count <= 2 else {
        throw StoreFailure.badInvocation("monkeys unpack <name> [directory]")
    }
    let destination = try unpackDestination(arguments.dropFirst().first)
    let bundle = try readBundle(from: bundlePath(name))
    for block in bundle.profiles {
        let names = block.values.map(\.name)
        try reconcileProjectFile(profile: block.profile, names: names, in: destination)
        for entry in block.values {
            try secretStore.store(entry.value, forName: block.profile + "/" + entry.name)
        }
        let stored = names.map { messageStyle(block.profile + "/" + $0, .bold) }.joined(separator: ", ")
        printToStandardError(messageStyle("stored", .good) + " " + stored)
    }
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
    case "copy": try runCopy(rest)
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
