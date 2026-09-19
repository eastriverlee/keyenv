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

func shellSingleQuoted(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

func requireName(_ arguments: [String]) throws -> String {
    guard let name = arguments.first else { throw StoreFailure.invalidVariableName("") }
    guard isValidVariableName(name) else { throw StoreFailure.invalidVariableName(name) }
    return name
}

func reportShellInit(appendedTo path: String) {
    printToStandardError("appended to \(abbreviatingHome(path)):")
    printToStandardError("  " + messageStyle(shellInitLine, .argument))
    printToStandardError("open a new shell, or: source \(abbreviatingHome(path))")
}

func runSet(_ arguments: [String]) throws {
    let name = try requireName(arguments)
    let value = readValueFromInput()
    guard !value.isEmpty else { throw StoreFailure.emptyValue }
    try secretStore.store(value, forName: name)
    printToStandardError(messageStyle("stored", .good) + " " + messageStyle(name, .bold))
    printHintToTerminal(messageStyle("give it to a command with:", .dim))
    printHintToTerminal("  " + messageStyle("monkeys run \(name) -- <command>", .argument))
}

func runRemove(_ arguments: [String]) throws {
    let name = try requireName(arguments)
    try secretStore.remove(forName: name)
    printToStandardError(messageStyle("removed", .good) + " " + messageStyle(name, .bold))
    guard isSetInThisEnvironment(name) else { return }
    printHintToTerminal(messageStyle("this shell still carries it; clear it with:", .dim))
    printHintToTerminal("  " + messageStyle("unset \(name)", .argument))
}

func runList() throws {
    for name in try secretStore.storedNames() { print(name) }
}

func runPreview(_ arguments: [String]) throws {
    let names = arguments.isEmpty ? try secretStore.storedNames() : arguments
    guard let width = names.map(\.count).max() else { return }
    for name in names {
        guard isValidVariableName(name) else { throw StoreFailure.invalidVariableName(name) }
        let masked = maskedValue(try secretStore.read(forName: name))
        print(name.padding(toLength: width, withPad: " ", startingAt: 0) + "  " + masked)
    }
}


func runExport(_ arguments: [String]) throws {
    let names = arguments.isEmpty ? try secretStore.storedNames() : arguments
    let lines = try names.map { name -> String in
        guard isValidVariableName(name) else { throw StoreFailure.invalidVariableName(name) }
        return "export \(name)=\(shellSingleQuoted(try secretStore.read(forName: name)))"
    }
    for line in lines { print(line) }
}

func runShellInit() throws {
    guard let path = shellProfilePath() else {
        printToStandardError(messageStyle("monkeys:", .bad) + " \(loginShellName()) has no startup file monkeys knows about.")
        printToStandardError("monkeys export prints POSIX shell syntax; add it yourself with:")
        printToStandardError("  \(shellInitLine)")
        exit(1)
    }
    guard !profileCallsMonkeysExport(path) else {
        printToStandardError("\(abbreviatingHome(path)) already calls monkeys export")
        return
    }
    try appendShellInit(to: path)
    reportShellInit(appendedTo: path)
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
    case "export": try runExport(rest)
    case "run": try runCommandWithSecrets(rest)
    case "shell-init": try runShellInit()
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
