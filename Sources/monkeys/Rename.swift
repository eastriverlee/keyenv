import Foundation

private let renameForm = "monkeys rename @old @new, or monkeys rename +old +new"

private func shownProfile(_ profile: String, in project: Project?) -> String {
    "@" + shortened(profile, in: project?.namespace)
}

private func shownPath(of project: Project) -> String {
    project.directory == FileManager.default.currentDirectoryPath ? projectFileName : abbreviatingHome(project.path)
}

private func storedKeys(under profile: String) throws -> [String] {
    try storedKeysInScope(Scope(profile: profile, project: nil))
}

private func storedProfiles(under namespace: String, in stored: [String]) -> [String] {
    let prefix = namespace + "."
    let profiles = stored.compactMap { name -> String? in
        guard let slash = name.firstIndex(of: "/") else { return nil }
        let profile = String(name[..<slash])
        return profile.hasPrefix(prefix) ? profile : nil
    }
    return Array(Set(profiles)).sorted()
}

private func reportMoved(_ keys: [String], from old: String, to new: String, project: Project?) {
    guard !keys.isEmpty else { return }
    let listed = keys.map { messageStyle($0, .bold) }.joined(separator: ", ")
    printToStandardError(messageStyle("moved", .good) + " \(shownProfile(old, in: project)) to \(shownProfile(new, in: project)): " + listed)
}

private func moveKeys(_ keys: [String], from old: String, to new: String, project: Project?) throws {
    var moved: [String] = []
    for key in keys {
        do {
            let secret = try secretStore.read(forName: old + "/" + key)
            try secretStore.store(secret, forName: new + "/" + key)
            try secretStore.remove(forName: old + "/" + key)
            moved.append(key)
        } catch {
            reportMoved(moved, from: old, to: new, project: project)
            throw StoreFailure.renameRefused("stopped at \(key): \(error); the keys before it moved and the rest did not")
        }
    }
    reportMoved(moved, from: old, to: new, project: project)
}

private func rewrittenLines(at path: String, _ rewrite: (String) -> String) throws -> String {
    let contents = try String(contentsOfFile: path, encoding: .utf8)
    return contents.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let changed = rewrite(trimmed)
        return changed == trimmed ? String(line) : changed
    }.joined(separator: "\n")
}

private func rewriteProfileLines(in project: Project, replacing old: String, with new: String) throws {
    let oldShort = project.shortName(old)
    let newShort = project.shortName(new)
    let renamingProfiles = { (line: String) -> String in
        guard line.hasPrefix("@") else { return line }
        let profiles = line.dropFirst().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return "@" + profiles.map { $0 == oldShort ? newShort : $0 }.joined(separator: ",")
    }
    let valuesPath = project.directory + "/" + valuesFileName
    let paths = [project.path] + (FileManager.default.fileExists(atPath: valuesPath) ? [valuesPath] : [])
    for path in paths {
        let rewritten = try rewrittenLines(at: path, renamingProfiles)
        try rewritten.write(toFile: path, atomically: true, encoding: .utf8)
        let shown = path == project.path ? shownPath(of: project) : valuesFileName
        printToStandardError(messageStyle("rewrote", .good) + " " + messageStyle(shown, .bold) + ": @\(oldShort) is now @\(newShort)")
    }
}

private func rewriteNamespaceLine(in project: Project, with new: String) throws {
    let rewritten = try rewrittenLines(at: project.path) { line in
        line.hasPrefix("+") ? "+" + new : line
    }
    try rewritten.write(toFile: project.path, atomically: true, encoding: .utf8)
    printToStandardError(messageStyle("rewrote", .good) + " " + messageStyle(shownPath(of: project), .bold) + ": +\(project.namespace ?? "") is now +\(new)")
}

private func fullName(_ given: String, under namespace: String?) -> String {
    guard let namespace, !given.contains(".") else { return given }
    return namespace + "." + given
}

private func fileCanName(_ profile: String, in project: Project) -> Bool {
    guard let namespace = project.namespace else { return true }
    return profile.hasPrefix(namespace + ".")
}

private func renameProfile(_ oldArgument: String, _ newArgument: String) throws {
    let (oldScope, _) = try resolveScope([oldArgument])
    guard let old = oldScope.profile else { throw StoreFailure.badInvocation(renameForm) }
    let project = try locateProject()
    let newName = String(newArgument.dropFirst())
    guard isValidProfileName(newName) else { throw StoreFailure.invalidProfileName(newArgument) }
    let isDeclared = project?.profiles.contains(old) ?? false
    let new = fullName(newName, under: isDeclared ? project?.namespace : nil)
    guard old != new else { throw StoreFailure.renameRefused("\(shownProfile(old, in: project)) is already its name") }
    let keys = try storedKeys(under: old)
    guard !keys.isEmpty || isDeclared else {
        throw StoreFailure.renameRefused("nothing is stored under \(shownProfile(old, in: project)), and no \(projectFileName) here names it")
    }
    let taken = try storedKeys(under: new)
    guard taken.isEmpty else {
        throw StoreFailure.renameRefused("\(shownProfile(new, in: project)) already holds \(taken.joined(separator: ", ")); a rename never merges two profiles. To merge, fill \(shownProfile(new, in: project)) --with \(shownProfile(old, in: project)), then remove what \(shownProfile(old, in: project)) still holds")
    }
    if isDeclared, let project {
        guard fileCanName(new, in: project) else {
            throw StoreFailure.renameRefused("\(shownPath(of: project)) names profiles under +\(project.namespace ?? ""), so \(shownProfile(new, in: project)) cannot go in it; rename the namespace with monkeys rename +\(project.namespace ?? "") +other, or fill the other project's profile")
        }
        guard !project.profiles.contains(new) else {
            throw StoreFailure.renameRefused("\(shownProfile(new, in: project)) is already declared in \(shownPath(of: project))")
        }
    }
    try moveKeys(keys, from: old, to: new, project: project)
    if isDeclared, let project {
        try rewriteProfileLines(in: project, replacing: old, with: new)
    }
}

private func renameNamespace(_ oldArgument: String, _ newArgument: String) throws {
    let old = String(oldArgument.dropFirst())
    let new = String(newArgument.dropFirst())
    for name in [old, new] where !isValidProfileName(name) {
        throw StoreFailure.renameRefused("+\(name) is not a namespace: letters, digits, _ - after the +, with a dot between parts")
    }
    guard old != new else { throw StoreFailure.renameRefused("+\(old) is already its name") }
    let project = try locateProject()
    let isDeclared = project?.namespace == old
    let stored = try secretStore.storedKeys()
    let profiles = storedProfiles(under: old, in: stored)
    guard !profiles.isEmpty || isDeclared else {
        throw StoreFailure.renameRefused("nothing is stored under +\(old), and no \(projectFileName) here names it")
    }
    let taken = storedProfiles(under: new, in: stored)
    guard taken.isEmpty else {
        let listed = taken.map { "@" + $0 }.joined(separator: ", ")
        throw StoreFailure.renameRefused("+\(new) already has \(listed); a rename never merges two namespaces. To merge, fill each profile of +\(new) --with the one of +\(old), then remove what +\(old) still holds")
    }
    for profile in profiles {
        let renamed = new + profile.dropFirst(old.count)
        try moveKeys(try storedKeys(under: profile), from: profile, to: renamed, project: nil)
    }
    if isDeclared, let project {
        try rewriteNamespaceLine(in: project, with: new)
    }
}

func runRename(_ arguments: [String]) throws {
    guard arguments.count == 2 else { throw StoreFailure.badInvocation(renameForm) }
    let (old, new) = (arguments[0], arguments[1])
    if old.hasPrefix("+"), new.hasPrefix("+") { return try renameNamespace(old, new) }
    guard old.hasPrefix("@"), new.hasPrefix("@") else { throw StoreFailure.badInvocation(renameForm) }
    guard old != "@", new != "@" else {
        throw StoreFailure.renameRefused("a bare @ is no profile, so it is neither a source nor a target here; a key moves into or out of it with fill or set")
    }
    try renameProfile(old, new)
}
