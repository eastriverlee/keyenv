import Foundation

private func reportRemoved(_ keys: [String], from shown: String) {
    guard !keys.isEmpty else { return }
    let listed = keys.map { messageStyle($0, .bold) }.joined(separator: ", ")
    printToStandardError(messageStyle("removed", .good) + " \(shown): " + listed)
}

private func removeEverything(under profile: String, shown: String) throws {
    let keys = try storedKeysInScope(Scope(profile: profile, project: nil))
    guard !keys.isEmpty else { throw StoreFailure.removeRefused("nothing is stored under \(shown)") }
    var removed: [String] = []
    for key in keys {
        do {
            try secretStore.remove(forName: profile + "/" + key)
            removed.append(key)
        } catch {
            reportRemoved(removed, from: shown)
            throw StoreFailure.removeRefused("stopped at \(key): \(error); the keys before it are gone and the rest are still stored")
        }
    }
    reportRemoved(removed, from: shown)
}

private func removeNamespace(_ argument: String) throws {
    let namespace = String(argument.dropFirst())
    guard isValidProfileName(namespace) else { throw StoreFailure.invalidProfileName(argument) }
    let profiles = storedProfiles(under: namespace, in: try secretStore.storedKeys())
    guard !profiles.isEmpty else { throw StoreFailure.removeRefused("nothing is stored under +\(namespace)") }
    for profile in profiles {
        try removeEverything(under: profile, shown: "@" + profile)
    }
}

func runRemoveProfiles(_ argument: String) throws {
    if argument.hasPrefix("+") { return try removeNamespace(argument) }
    guard argument != "@" else {
        throw StoreFailure.removeRefused("a bare @ is no profile; name the key to remove: monkeys remove @ <KEY>")
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
