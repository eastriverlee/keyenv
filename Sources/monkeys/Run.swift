import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

func runCommandWithSecrets(_ arguments: [String]) throws -> Never {
    guard let separator = arguments.firstIndex(of: "--") else {
        throw StoreFailure.badInvocation("monkeys run [NAME...] -- <command> [argument...]")
    }
    let command = Array(arguments[arguments.index(after: separator)...])
    guard let executable = command.first else {
        throw StoreFailure.badInvocation("monkeys run [NAME...] -- <command> [argument...]")
    }

    let requested = Array(arguments[..<separator])
    let names = requested.isEmpty ? try secretStore.storedNames() : requested

    var values: [(name: String, value: String)] = []
    var missing: [String] = []
    for name in names {
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
    execvp(executable, &argumentVector)
    throw StoreFailure.backendFailed("cannot run \(executable): \(String(cString: strerror(errno)))")
}
