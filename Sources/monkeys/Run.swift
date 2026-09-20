import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

let runInvocation = "monkeys run [@profile] <KEY[,KEY...]> <command>, monkeys run [@profile] --all <command>, or monkeys run [@profile] <command> next to a \(projectFileName) file"

private func namesToSpend(_ scope: Scope, _ arguments: [String]) throws -> (keys: [String], command: [String]) {
    if arguments.first == "--all" {
        return (try storedKeysInScope(scope), Array(arguments.dropFirst()))
    }
    if let keys = scope.projectKeys {
        try rejectListedNames(arguments.first, keys, scope)
        return (keys, arguments)
    }
    guard let list = arguments.first else { throw StoreFailure.badInvocation(runInvocation) }
    let keys = list.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    return (keys, Array(arguments.dropFirst()))
}

private func rejectListedNames(_ first: String?, _ listed: [String], _ scope: Scope) throws {
    guard let first, let project = scope.project else { return }
    let given = first.split(separator: ",").map(String.init)
    guard !given.isEmpty, given.allSatisfy(listed.contains) else { return }
    throw StoreFailure.namesAlreadyListed(given, scope.profile ?? "", abbreviatingHome(project.path))
}

func runCommandWithSecrets(_ arguments: [String]) throws -> Never {
    let (scope, rest) = try resolveScope(arguments)
    let (keys, command) = try namesToSpend(scope, rest)
    guard !command.isEmpty else { throw StoreFailure.badInvocation(runInvocation) }
    let publicValues = spentValues(of: scope.project, for: scope.profile)

    var values: [SpentValue] = []
    var missing: [String] = []
    for name in keys {
        guard isValidKey(name) else { throw StoreFailure.invalidKey(name) }
        do {
            values.append(SpentValue(name: name, value: try secretStore.read(forName: scope.storedName(name))))
        } catch StoreFailure.keyNotStored {
            missing.append(name)
        }
    }
    guard missing.isEmpty else { throw StoreFailure.keysNotStored(missing, scope.profileArgument) }
    for entry in publicValues { setenv(entry.name, entry.value, 1) }
    runRedacted(command, values)
}
