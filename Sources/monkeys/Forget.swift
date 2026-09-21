import Foundation

private func reportForgotten(_ keys: [String], from shown: String) {
    guard !keys.isEmpty else { return }
    let listed = keys.map { messageStyle($0, .bold) }.joined(separator: ", ")
    printToStandardError(messageStyle("forgot", .good) + " \(shown): " + listed)
}

private func removeEverything(under profile: String, shown: String, asked: Bool = false) throws {
    let keys = try storedKeysInScope(Scope(profile: profile, project: nil))
    guard !keys.isEmpty else { throw StoreFailure.forgetRefused("nothing is remembered under \(shown)") }
    if !asked { try confirmedForget("forget \(counted(keys.count)) under \(shown), which nothing else holds") }
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

private func counted(_ keys: Int) -> String {
    keys == 1 ? "1 secret" : "\(keys) secrets"
}

private func removeNamespace(_ argument: String) throws {
    let namespace = String(argument.dropFirst())
    guard isValidProfileName(namespace) else { throw StoreFailure.invalidProfileName(argument) }
    let profiles = storedProfiles(under: namespace, in: try secretStore.storedKeys())
    guard !profiles.isEmpty else { throw StoreFailure.forgetRefused("nothing is remembered under +\(namespace)") }
    let total = try profiles.reduce(0) { running, profile in
        running + (try storedKeysInScope(Scope(profile: profile, project: nil)).count)
    }
    try confirmedForget(
        "forget \(counted(total)) across \(profiles.count) profiles under +\(namespace), which nothing else holds")
    for profile in profiles {
        try removeEverything(under: profile, shown: "@" + profile, asked: true)
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
    let profiles = resolved.compactMap(\.profile)
    let total = try profiles.reduce(0) { running, profile in
        running + (try storedKeysInScope(Scope(profile: profile, project: nil)).count)
    }
    let shownNames = profiles.map { "@" + shortened($0, in: project?.namespace) }.joined(separator: ", ")
    try confirmedForget("forget \(counted(total)) under \(shownNames), which nothing else holds")
    for profile in profiles {
        try removeEverything(under: profile, shown: "@" + shortened(profile, in: project?.namespace), asked: true)
    }
}
