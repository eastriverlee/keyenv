import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

let runInvocation = "monkeys run [@profile] <NAME>[,<NAME>...] <command>, monkeys run [@profile] --all <command>, or monkeys run [@profile] <command> next to a \(projectFileName) file"

private func namesToSpend(_ scope: Scope, _ arguments: [String]) throws -> (names: [String], command: [String]) {
    if arguments.first == "--all" {
        return (try storedNamesInScope(scope), Array(arguments.dropFirst()))
    }
    if let names = scope.projectNames {
        return (names, arguments)
    }
    guard let list = arguments.first else { throw StoreFailure.badInvocation(runInvocation) }
    let names = list.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    return (names, Array(arguments.dropFirst()))
}

private func describeExecFailure(_ command: String, _ scope: Scope) -> String {
    let reason = "cannot run \(command): \(String(cString: strerror(errno)))"
    guard let project = scope.project else { return reason }
    return reason + "\n\(abbreviatingHome(project.path)) supplies the names here, so everything after run is the command"
}

func runCommandWithSecrets(_ arguments: [String]) throws -> Never {
    let (scope, rest) = try resolveScope(arguments)
    let (names, command) = try namesToSpend(scope, rest)
    guard !command.isEmpty else { throw StoreFailure.badInvocation(runInvocation) }

    var values: [(name: String, value: String)] = []
    var missing: [String] = []
    for name in names {
        guard isValidVariableName(name) else { throw StoreFailure.invalidVariableName(name) }
        do {
            values.append((name, try secretStore.read(forName: scope.storedName(name))))
        } catch StoreFailure.nameNotStored {
            missing.append(name)
        }
    }
    guard missing.isEmpty else { throw StoreFailure.namesNotStored(missing, scope.profileArgument) }
    for entry in values { setenv(entry.name, entry.value, 1) }

    var argumentVector = command.map { strdup($0) } + [nil]
    execvp(command[0], &argumentVector)
    throw StoreFailure.backendFailed(describeExecFailure(command[0], scope))
}
