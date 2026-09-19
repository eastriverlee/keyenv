import Foundation
import Security

let serviceName = "keyenv"

enum KeychainFailure: Error {
    case unexpectedStatus(OSStatus)
    case nameNotStored(String)
    case invalidVariableName(String)
    case emptyValue
}

extension KeychainFailure: CustomStringConvertible {
    var description: String {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown error"
            return "keychain returned \(status): \(message)"
        case .nameNotStored(let name):
            return "\(name) is not stored"
        case .invalidVariableName(let name):
            return "\(name) is not a valid environment variable name"
        case .emptyValue:
            return "no value was given"
        }
    }
}

func isValidVariableName(_ name: String) -> Bool {
    guard let first = name.first else { return false }
    guard first.isLetter || first == "_" else { return false }
    return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" } && first.isASCII
}

func keychainQuery(forName name: String) -> [String: Any] {
    [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: serviceName,
        kSecAttrAccount as String: name,
    ]
}

func storeValue(_ value: String, forName name: String) throws {
    let data = Data(value.utf8)
    let existing = keychainQuery(forName: name)
    let updateStatus = SecItemUpdate(
        existing as CFDictionary,
        [kSecValueData as String: data] as CFDictionary
    )
    if updateStatus == errSecSuccess { return }
    guard updateStatus == errSecItemNotFound else { throw KeychainFailure.unexpectedStatus(updateStatus) }

    var creation = existing
    creation[kSecValueData as String] = data
    creation[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    creation[kSecAttrLabel as String] = "\(serviceName): \(name)"
    let addStatus = SecItemAdd(creation as CFDictionary, nil)
    guard addStatus == errSecSuccess else { throw KeychainFailure.unexpectedStatus(addStatus) }
}

func readValue(forName name: String) throws -> String {
    var query = keychainQuery(forName: name)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { throw KeychainFailure.nameNotStored(name) }
    guard status == errSecSuccess else { throw KeychainFailure.unexpectedStatus(status) }
    guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
        throw KeychainFailure.unexpectedStatus(errSecDecode)
    }
    return value
}

func removeValue(forName name: String) throws {
    let status = SecItemDelete(keychainQuery(forName: name) as CFDictionary)
    if status == errSecItemNotFound { throw KeychainFailure.nameNotStored(name) }
    guard status == errSecSuccess else { throw KeychainFailure.unexpectedStatus(status) }
}

func storedNames() throws -> [String] {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: serviceName,
        kSecMatchLimit as String: kSecMatchLimitAll,
        kSecReturnAttributes as String: true,
    ]

    var items: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &items)
    if status == errSecItemNotFound { return [] }
    guard status == errSecSuccess else { throw KeychainFailure.unexpectedStatus(status) }
    guard let attributes = items as? [[String: Any]] else { return [] }
    return attributes.compactMap { $0[kSecAttrAccount as String] as? String }.sorted()
}

func readValueFromInput() -> String {
    if isatty(STDIN_FILENO) == 0 {
        let piped = FileHandle.standardInput.readDataToEndOfFile()
        return String(decoding: piped, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard let entered = getpass("Value: ") else { return "" }
    return String(cString: entered)
}

func shellSingleQuoted(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

func printToStandardError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

let usage = """
keyenv — environment variables kept in the macOS keychain

  keyenv set <NAME>        read a value from the terminal (hidden) or stdin and store it
  keyenv get <NAME>        print one stored value
  keyenv list              print every stored name
  keyenv remove <NAME>     delete one stored value
  keyenv export [NAME...]  print shell export lines; all names when none are given

In ~/.zshrc:

  eval "$(keyenv export)"
"""

func requireName(_ arguments: [String]) throws -> String {
    guard let name = arguments.first else { throw KeychainFailure.invalidVariableName("") }
    guard isValidVariableName(name) else { throw KeychainFailure.invalidVariableName(name) }
    return name
}

func runSet(_ arguments: [String]) throws {
    let name = try requireName(arguments)
    let value = readValueFromInput()
    guard !value.isEmpty else { throw KeychainFailure.emptyValue }
    try storeValue(value, forName: name)
    printToStandardError("stored \(name)")
}

func runGet(_ arguments: [String]) throws {
    print(try readValue(forName: try requireName(arguments)))
}

func runRemove(_ arguments: [String]) throws {
    let name = try requireName(arguments)
    try removeValue(forName: name)
    printToStandardError("removed \(name)")
}

func runList() throws {
    for name in try storedNames() { print(name) }
}

func runExport(_ arguments: [String]) throws {
    let names = arguments.isEmpty ? try storedNames() : arguments
    for name in names {
        guard isValidVariableName(name) else { throw KeychainFailure.invalidVariableName(name) }
        print("export \(name)=\(shellSingleQuoted(try readValue(forName: name)))")
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
    case "get": try runGet(rest)
    case "list": try runList()
    case "remove": try runRemove(rest)
    case "export": try runExport(rest)
    case "help", "-h", "--help": print(usage)
    default:
        printToStandardError("unknown command: \(command)")
        printToStandardError(usage)
        exit(2)
    }
} catch let failure as KeychainFailure {
    printToStandardError("keyenv: \(failure)")
    exit(1)
} catch {
    printToStandardError("keyenv: \(error)")
    exit(1)
}
