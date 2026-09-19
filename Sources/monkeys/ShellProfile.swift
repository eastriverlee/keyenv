import Foundation

let shellInitLine = "eval \"$(monkeys export)\""

private let shellInitBlock = """

# secrets from the keyring, via https://github.com/eastriverlee/monkeys
\(shellInitLine)

"""

func homeDirectory() -> String {
    if let home = ProcessInfo.processInfo.environment["HOME"], !home.isEmpty { return home }
    return FileManager.default.homeDirectoryForCurrentUser.path
}

func abbreviatingHome(_ path: String) -> String {
    let home = homeDirectory()
    guard path.hasPrefix(home) else { return path }
    return "~" + path.dropFirst(home.count)
}

func loginShellName() -> String {
    let shell = ProcessInfo.processInfo.environment["SHELL"] ?? ""
    return URL(fileURLWithPath: shell).lastPathComponent
}

func shellProfilePath() -> String? {
    if let chosen = ProcessInfo.processInfo.environment["MONKEYS_SHELL_PROFILE"], !chosen.isEmpty {
        return chosen
    }
    switch loginShellName() {
    case "zsh":
        return homeDirectory() + "/.zshrc"
    case "bash":
        #if os(macOS)
        return homeDirectory() + "/.bash_profile"
        #else
        return homeDirectory() + "/.bashrc"
        #endif
    default:
        return nil
    }
}

func profileCallsMonkeysExport(_ path: String) -> Bool {
    guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return false }
    return contents.contains("monkeys export")
}

func appendShellInit(to path: String) throws {
    let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
    try (existing + shellInitBlock).write(toFile: path, atomically: true, encoding: .utf8)
}
