import Foundation

private func keyringLookup(_ storedName: String) -> String {
    #if os(macOS)
    return "security find-generic-password -s \(serviceName) -a \(storedName) -w"
    #else
    return "secret-tool lookup service \(serviceName) account \(storedName)"
    #endif
}

func startupLine(_ scope: Scope, _ name: String) -> String {
    "export \(name)=\"$(\(keyringLookup(scope.storedName(name))))\""
}

func runExport(_ arguments: [String]) throws {
    let (scope, rest) = try resolveScope(arguments)
    let names = try validatedNames(scope, rest)
    let stored = Set(try secretStore.storedNames())
    let missing = names.filter { !stored.contains(scope.storedName($0)) }
    guard missing.isEmpty else { throw StoreFailure.namesNotStored(missing, scope.profileArgument) }
    for name in names { print(startupLine(scope, name)) }
}
