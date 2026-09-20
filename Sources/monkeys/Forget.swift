import Foundation

private func reportForgotten(_ keys: [String], from shown: String) {
    guard !keys.isEmpty else { return }
    let listed = keys.map { messageStyle($0, .bold) }.joined(separator: ", ")
    printToStandardError(messageStyle("forgot", .good) + " \(shown): " + listed)
}

private func removeEverything(under profile: String, shown: String) throws {
    let keys = try storedKeysInScope(Scope(profile: profile, project: nil))
    guard !keys.isEmpty else { throw StoreFailure.forgetRefused("nothing is remembered under \(shown)") }
    var removed: [String] = []
    for key in keys {
        do {
            try secretStore.remove(forName: profile + "/" + key)
            removed.append(key)
        } catch {
            reportForgotten(removed, from: shown)
            throw StoreFailure.forgetRefused("stopped at \(key): \(error); the keys before it are gone and the rest are still remembered")
        }
    }
    reportForgotten(removed, from: shown)
}

private func removeNamespace(_ argument: String) throws {
    let namespace = String(argument.dropFirst())
    guard isValidProfileName(namespace) else { throw StoreFailure.invalidProfileName(argument) }
    let profiles = storedProfiles(under: namespace, in: try secretStore.storedKeys())
    guard !profiles.isEmpty else { throw StoreFailure.forgetRefused("nothing is remembered under +\(namespace)") }
    for profile in profiles {
        try removeEverything(under: profile, shown: "@" + profile)
    }
}

func runForgetProfiles(_ argument: String) throws {
    if argument.hasPrefix("+") { return try removeNamespace(argument) }
    guard argument != "@" else {
        throw StoreFailure.forgetRefused("a bare @ is no profile; name the key to forget: monkeys forget @ <KEY>")
    }
    let project = try locateProject()
    let names = argument.dropFirst().split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    let resolved = try names.map { name -> Scope in
        guard isValidProfileName(name) else { throw StoreFailure.invalidProfileName("@" + name) }
        return try scope(for: .named(name))
    }
    for scope in resolved {
        guard let profile = scope.profile else { continue }
        try removeEverything(under: profile, shown: "@" + shortened(profile, in: project?.namespace))
    }
}
