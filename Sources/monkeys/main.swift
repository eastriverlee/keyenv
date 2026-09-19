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

func runPack(_ arguments: [String]) throws {
    let (scope, rest) = try resolveScope(arguments)
    guard rest.count <= 1 else { throw StoreFailure.badInvocation("monkeys pack [@profile] [name]") }
    guard let profile = scope.profile else {
        throw StoreFailure.bundleFailed("a bundle carries a profile: run this in a project with a \(projectFileName) file, or name one with @profile")
    }
    let path = bundlePath(rest.first ?? profile)
    var values: [(name: String, value: String)] = []
    var missing: [String] = []
    for name in try namesInScope(scope) {
        do {
            values.append((name, try secretStore.read(forName: scope.storedName(name))))
        } catch StoreFailure.nameNotStored {
            missing.append(name)
        }
    }
    guard missing.isEmpty else { throw StoreFailure.namesNotStored(missing, scope.profileArgument) }
    try writeBundle(ProfileBundle(profile: profile, values: values), to: path)
    printToStandardError(messageStyle("wrote", .good) + " " + messageStyle(path, .bold) + ": @\(profile), \(values.count) value\(values.count == 1 ? "" : "s")")
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
    let names = bundle.values.map(\.name)
    try reconcileProjectFile(profile: bundle.profile, names: names, in: destination)
    for entry in bundle.values {
        try secretStore.store(entry.value, forName: bundle.profile + "/" + entry.name)
    }
    let stored = names.map { messageStyle(bundle.profile + "/" + $0, .bold) }.joined(separator: ", ")
    printToStandardError(messageStyle("stored", .good) + " " + stored)
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
