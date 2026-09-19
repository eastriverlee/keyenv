import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

let runInvocation = "monkeys run [--no-redact] [@profile] <NAME>[,<NAME>...] <command>, monkeys run [--no-redact] [@profile] --all <command>, or monkeys run [--no-redact] [@profile] <command> next to a \(projectFileName) file"
let noRedactFlag = "--no-redact"

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

private func withoutRedactFlag(_ arguments: [String]) -> (arguments: [String], isRedacting: Bool) {
    var remaining = arguments
    var isRedacting = true
    for slot in 0..<min(2, remaining.count) where remaining[slot] == noRedactFlag {
        remaining.remove(at: slot)
        isRedacting = false
        break
    }
    return (remaining, isRedacting)
}

func runCommandWithSecrets(_ arguments: [String]) throws -> Never {
    let (cleaned, isRedacting) = withoutRedactFlag(arguments)
    let (scope, rest) = try resolveScope(cleaned)
    let (names, command) = try namesToSpend(scope, rest)
    guard !command.isEmpty else { throw StoreFailure.badInvocation(runInvocation) }

    var values: [SpentValue] = []
    var missing: [String] = []
    for name in names {
        guard isValidVariableName(name) else { throw StoreFailure.invalidVariableName(name) }
        do {
            values.append(SpentValue(name: name, value: try secretStore.read(forName: scope.storedName(name))))
        } catch StoreFailure.nameNotStored {
            missing.append(name)
        }
    }
    guard missing.isEmpty else { throw StoreFailure.namesNotStored(missing, scope.profileArgument) }
    if isRedacting { runRedacted(command, values) }
    runUnredacted(command, values)
}
