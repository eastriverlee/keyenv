import Foundation

func vaultLookup(_ storedName: String) -> String {
    #if os(macOS)
    return "security find-generic-password -s \(serviceName) -a \(storedName) -w"
    #else
    return "secret-tool lookup service \(serviceName) account \(storedName)"
    #endif
}

func startupLine(_ scope: Scope, _ name: String) -> String {
    "export \(name)=\"$(\(vaultLookup(scope.storedName(name))))\""
}

func runExport(_ arguments: [String]) throws {
    let (scope, rest) = try resolveScope(arguments)
    let keys = try validatedKeys(scope, rest)
    let stored = Set(try secretStore.storedKeys())
    let missing = keys.filter { !stored.contains(scope.storedName($0)) }
    guard missing.isEmpty else { throw StoreFailure.keysNotStored(missing, scope.profileArgument) }
    for name in keys { print(startupLine(scope, name)) }
}
