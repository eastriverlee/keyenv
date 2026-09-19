import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

let runInvocation = "monkeys run <NAME>[,<NAME>...] <command>, or monkeys run --all <command>"

private func namesToSpend(_ list: String) throws -> [String] {
    guard list != "--all" else { return try secretStore.storedNames() }
    return list.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
}

func runCommandWithSecrets(_ arguments: [String]) throws -> Never {
    guard let list = arguments.first, arguments.count > 1 else {
        throw StoreFailure.badInvocation(runInvocation)
    }
    let command = Array(arguments.dropFirst())

    var values: [(name: String, value: String)] = []
    var missing: [String] = []
    for name in try namesToSpend(list) {
        guard isValidVariableName(name) else { throw StoreFailure.invalidVariableName(name) }
        do {
            values.append((name, try secretStore.read(forName: name)))
        } catch StoreFailure.nameNotStored {
            missing.append(name)
        }
    }
    guard missing.isEmpty else { throw StoreFailure.namesNotStored(missing) }
    for entry in values { setenv(entry.name, entry.value, 1) }

    var argumentVector = command.map { strdup($0) } + [nil]
    execvp(command[0], &argumentVector)
    throw StoreFailure.backendFailed("cannot run \(command[0]): \(String(cString: strerror(errno)))")
}
