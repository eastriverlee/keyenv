import Foundation

let projectFileName = ".monkeys"

func homeDirectory() -> String {
    if let home = ProcessInfo.processInfo.environment["HOME"], !home.isEmpty { return home }
    return FileManager.default.homeDirectoryForCurrentUser.path
}

func abbreviatingHome(_ path: String) -> String {
    let home = homeDirectory()
    guard path.hasPrefix(home) else { return path }
    return "~" + path.dropFirst(home.count)
}

struct Block {
    let profiles: [String]
    let keys: [String]
    var values: [ValueEntry] = []
}

func prefixed(_ profile: String, with namespace: String?) -> String {
    guard let namespace else { return profile }
    return namespace + "." + profile
}

func shortened(_ profile: String, in namespace: String?) -> String {
    guard let namespace, profile.hasPrefix(namespace + ".") else { return profile }
    return String(profile.dropFirst(namespace.count + 1))
}

struct Project {
    let directory: String
    let namespace: String?
    let blocks: [Block]

    var path: String { directory + "/" + projectFileName }

    var profiles: [String] {
        var seen: [String] = []
        for profile in blocks.flatMap(\.profiles) where !seen.contains(profile) { seen.append(profile) }
        return seen
    }

    var defaultProfile: String { profiles[0] }

    func keys(for profile: String) -> [String] {
        blocks.filter { $0.profiles.contains(profile) }.flatMap(\.keys)
    }

    func values(for profile: String) -> [ValueEntry] {
        blocks.filter { $0.profiles.contains(profile) }.flatMap(\.values)
    }

    func value(of key: String, for profile: String) -> String? {
        values(for: profile).first { $0.key == key }?.value
    }

    func shortName(_ profile: String) -> String {
        shortened(profile, in: namespace)
    }

    func profile(matching given: String) throws -> String {
        if profiles.contains(given) { return given }
        let full = prefixed(given, with: namespace)
        if profiles.contains(full) { return full }
        let byShortPrefix = profiles.filter { shortName($0).hasPrefix(given) }
        let candidates = byShortPrefix.isEmpty ? profiles.filter { $0.hasPrefix(given) } : byShortPrefix
        switch candidates.count {
        case 1: return candidates[0]
        case 0: throw StoreFailure.profileNotDeclared(given, profiles.map(shortName), abbreviatingHome(path))
        default: throw StoreFailure.profileAmbiguous(given, candidates.map(shortName))
        }
    }
}

struct Scope {
    let profile: String?
    let project: Project?

    static let noProfile = Scope(profile: nil, project: nil)

    func storedName(_ key: String) -> String {
        guard let profile else { return key }
        return profile + "/" + key
    }

    var profileArgument: String {
        guard let profile else { return "" }
        return "@" + profile + " "
    }

    var shownProfile: String {
        guard let profile else { return "@" }
        guard let project, projectKeys != nil else { return "@" + profile }
        return "@" + project.shortName(profile)
    }

    var projectKeys: [String]? {
        guard let project, let profile, project.profiles.contains(profile) else { return nil }
        return project.keys(for: profile)
    }
}

func isValidProfileName(_ name: String) -> Bool {
    let parts = name.split(separator: ".", omittingEmptySubsequences: false)
    return parts.allSatisfy { part in
        !part.isEmpty && part.allSatisfy { ($0.isASCII && ($0.isLetter || $0.isNumber)) || "_-".contains($0) }
    }
}

enum ProfileArgument {
    case none
    case noProfile
    case named(String)
}

func takeProfileArgument(_ arguments: [String]) throws -> (profile: ProfileArgument, rest: [String]) {
    guard let first = arguments.first, first.hasPrefix("@") else { return (.none, arguments) }
    let rest = Array(arguments.dropFirst())
    guard first != "@" else { return (.noProfile, rest) }
    let name = String(first.dropFirst())
    guard isValidProfileName(name) else { throw StoreFailure.invalidProfileName(first) }
    return (.named(name), rest)
}

func scope(for chosen: ProfileArgument) throws -> Scope {
    switch chosen {
    case .noProfile:
        return .noProfile
    case .named(let name):
        guard let project = try locateProject() else { return Scope(profile: name, project: nil) }
        do {
            return Scope(profile: try project.profile(matching: name), project: project)
        } catch StoreFailure.profileNotDeclared where name.contains(".") {
            return Scope(profile: name, project: nil)
        }
    case .none:
        let project = try locateProject()
        return Scope(profile: project?.defaultProfile, project: project)
    }
}

func resolveScope(_ arguments: [String]) throws -> (scope: Scope, rest: [String]) {
    let (chosen, rest) = try takeProfileArgument(arguments)
    return (try scope(for: chosen), rest)
}

func locateProject() throws -> Project? {
    for directory in directoriesOfThisCheckout() {
        let path = directory + "/" + projectFileName
        if FileManager.default.fileExists(atPath: path) {
            try rejectingRetiredValuesFile(in: directory)
            return try parseProject(at: path, directory: directory)
        }
    }
    return nil
}

private func directoriesOfThisCheckout() -> [String] {
    var directory = FileManager.default.currentDirectoryPath
    var climbed: [String] = []
    while true {
        climbed.append(directory)
        if FileManager.default.fileExists(atPath: directory + "/.git") { return climbed }
        guard directory != "/" else { return [climbed[0]] }
        directory = URL(fileURLWithPath: directory).deletingLastPathComponent().path
    }
}

private func parseProfileLine(_ line: String, in shown: String) throws -> [String] {
    let profiles = line.dropFirst().split(separator: ",", omittingEmptySubsequences: false).map {
        $0.trimmingCharacters(in: .whitespaces)
    }
    for profile in profiles where !isValidProfileName(profile) {
        throw StoreFailure.badProjectFile(shown, "\(line) is not a profile line: @name or @name,name")
    }
    return profiles
}

private func rejectingDuplicates(_ blocks: [Block], in shown: String, namespace: String?) throws {
    var seen: [String: Set<String>] = [:]
    for block in blocks {
        for profile in block.profiles {
            for name in block.keys + block.values.map(\.key) {
                guard seen[profile, default: []].insert(name).inserted else {
                    throw StoreFailure.badProjectFile(shown, "\(name) is listed twice for @\(shortened(profile, in: namespace))")
                }
            }
        }
    }
}

func parseProject(at path: String, directory: String) throws -> Project {
    let contents = try String(contentsOfFile: path, encoding: .utf8)
    let shown = abbreviatingHome(path)
    var namespace: String?
    var blocks: [Block] = []
    var profiles: [String]?
    var keys: [String] = []
    var values: [ValueEntry] = []
    func closeBlock() {
        if let open = profiles { blocks.append(Block(profiles: open, keys: keys, values: values)) }
        keys = []
        values = []
    }
    for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }
        if line.hasPrefix("+") {
            guard namespace == nil, profiles == nil else {
                throw StoreFailure.badProjectFile(shown, "\(line): a file has one +namespace line, and it comes first")
            }
            let name = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            guard isValidProfileName(name) else {
                throw StoreFailure.badProjectFile(shown, "\(line) is not a namespace line: +name, with letters, digits, _ - .")
            }
            namespace = name
            continue
        }
        if line.hasPrefix("@") {
            closeBlock()
            profiles = try parseProfileLine(line, in: shown).map { prefixed($0, with: namespace) }
            continue
        }
        guard profiles != nil else {
            throw StoreFailure.badProjectFile(shown, "\(line) comes before any @profile line; a project's keys live in a named profile")
        }
        if let entry = splitValueLine(line) {
            values.append(entry)
            continue
        }
        guard isValidKey(line) else {
            throw StoreFailure.badProjectFile(shown, "\(line) is not a key (an environment variable name), nor KEY=value")
        }
        keys.append(line)
    }
    closeBlock()
    guard !blocks.isEmpty else {
        throw StoreFailure.badProjectFile(shown, "no @profile line; a project's keys live in a named profile")
    }
    try rejectingDuplicates(blocks, in: shown, namespace: namespace)
    return Project(directory: directory, namespace: namespace, blocks: blocks)
}

func storedKeysInScope(_ scope: Scope) throws -> [String] {
    let stored = try secretStore.storedKeys()
    guard let profile = scope.profile else { return stored.filter { !$0.contains("/") } }
    let prefix = profile + "/"
    return stored.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
}

func keysInScope(_ scope: Scope) throws -> [String] {
    if let keys = scope.projectKeys { return keys }
    return try storedKeysInScope(scope)
}

func splitValueLine(_ line: String) -> ValueEntry? {
    guard let equals = line.firstIndex(of: "=") else { return nil }
    let key = String(line[..<equals])
    guard isValidKey(key) else { return nil }
    return ValueEntry(key: key, value: String(line[line.index(after: equals)...]))
}

private func rejectingRetiredValuesFile(in directory: String) throws {
    let path = directory + "/" + retiredValuesFileName
    guard FileManager.default.fileExists(atPath: path) else { return }
    throw StoreFailure.retiredValuesFile(abbreviatingHome(path))
}
