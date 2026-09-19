import Foundation

let serviceName = "keyenv"

enum StoreFailure: Error {
    case nameNotStored(String)
    case invalidVariableName(String)
    case emptyValue
    case backendUnavailable(String)
    case backendFailed(String)
}

extension StoreFailure: CustomStringConvertible {
    var description: String {
        switch self {
        case .nameNotStored(let name):
            return "\(name) is not stored"
        case .invalidVariableName(let name):
            return "\(name) is not a valid environment variable name"
        case .emptyValue:
            return "no value was given"
        case .backendUnavailable(let reason):
            return reason
        case .backendFailed(let reason):
            return reason
        }
    }
}

protocol SecretStore: Sendable {
    func store(_ value: String, forName name: String) throws
    func read(forName name: String) throws -> String
    func remove(forName name: String) throws
    func storedNames() throws -> [String]
}

#if os(macOS)
let secretStore: SecretStore = KeychainStore()
#elseif os(Linux)
let secretStore: SecretStore = SecretServiceStore()
#else
#error("keyenv has no secret store for this platform")
#endif

func isValidVariableName(_ name: String) -> Bool {
    guard let first = name.first, first.isASCII else { return false }
    guard first.isLetter || first == "_" else { return false }
    return name.allSatisfy { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "_" }
}
