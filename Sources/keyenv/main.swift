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
    FileHandle.standardError.write(Data((question + " [y/N] ").utf8))
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

let usage = """
keyenv - environment variables kept in your operating system's keyring

  keyenv set <NAME>        read a value from the terminal (hidden) or stdin and store it
  keyenv get <NAME>        print one stored value
  keyenv list              print every stored name
  keyenv remove <NAME>     delete one stored value
  keyenv export [NAME...]  print shell export lines; all names when none are given
  keyenv shell-init        add the export line to your shell startup file

In your shell startup file:

  \(shellInitLine)
"""

func requireName(_ arguments: [String]) throws -> String {
    guard let name = arguments.first else { throw StoreFailure.invalidVariableName("") }
    guard isValidVariableName(name) else { throw StoreFailure.invalidVariableName(name) }
    return name
}

func reportShellInit(appendedTo path: String) {
    printToStandardError("appended to \(abbreviatingHome(path)):")
    printToStandardError("  \(shellInitLine)")
    printToStandardError("open a new shell, or: source \(abbreviatingHome(path))")
}

func offerShellInit() {
    guard isTerminal(STDERR_FILENO) else { return }
    guard let path = shellProfilePath(), !profileCallsKeyenvExport(path) else { return }

    printToStandardError("")
    printToStandardError("no startup file here seems to call keyenv export.")
    guard askYesOrNo("append it to \(abbreviatingHome(path)) now?") else {
        printToStandardError("you can do it later with: keyenv shell-init")
        return
    }
    do {
        try appendShellInit(to: path)
        reportShellInit(appendedTo: path)
    } catch {
        printToStandardError("keyenv: \(error)")
    }
}

func runSet(_ arguments: [String]) throws {
    let name = try requireName(arguments)
    let value = readValueFromInput()
    guard !value.isEmpty else { throw StoreFailure.emptyValue }
    try secretStore.store(value, forName: name)
    printToStandardError("stored \(name)")
    printHintToTerminal("this shell still has the value it started with; load the stored one with:")
    printHintToTerminal("  eval \"$(keyenv export \(name))\"")
    offerShellInit()
}

func runGet(_ arguments: [String]) throws {
    print(try secretStore.read(forName: try requireName(arguments)))
}

func runRemove(_ arguments: [String]) throws {
    let name = try requireName(arguments)
    try secretStore.remove(forName: name)
    printToStandardError("removed \(name)")
    guard isSetInThisEnvironment(name) else { return }
    printHintToTerminal("this shell still carries it; clear it with:")
    printHintToTerminal("  unset \(name)")
}

func runList() throws {
    for name in try secretStore.storedNames() { print(name) }
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
        printToStandardError("keyenv: \(loginShellName()) has no startup file keyenv knows about.")
        printToStandardError("keyenv export prints POSIX shell syntax; add it yourself with:")
        printToStandardError("  \(shellInitLine)")
        exit(1)
    }
    guard !profileCallsKeyenvExport(path) else {
        printToStandardError("\(abbreviatingHome(path)) already calls keyenv export")
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
    case "get": try runGet(rest)
    case "list": try runList()
    case "remove": try runRemove(rest)
    case "export": try runExport(rest)
    case "shell-init": try runShellInit()
    case "help", "-h", "--help": print(usage)
    default:
        printToStandardError("unknown command: \(command)")
        printToStandardError(usage)
        exit(2)
    }
} catch let failure as StoreFailure {
    printToStandardError("keyenv: \(failure)")
    exit(1)
} catch {
    printToStandardError("keyenv: \(error)")
    exit(1)
}
