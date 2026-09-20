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
}

struct Project {
    let directory: String
    let namespace: String
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

    func qualified(_ profile: String) -> String {
        namespace + "/" + profile
    }

    func profile(matching given: String) throws -> String {
        if let dot = given.firstIndex(of: ".") {
            let space = String(given[..<dot])
            guard space == namespace else { throw StoreFailure.namespaceMismatch(space, namespace, abbreviatingHome(path)) }
            return try profile(matching: String(given[given.index(after: dot)...]))
        }
        if profiles.contains(given) { return given }
        let candidates = profiles.filter { $0.hasPrefix(given) }
        switch candidates.count {
        case 1: return candidates[0]
        case 0: throw StoreFailure.profileNotDeclared(given, profiles, abbreviatingHome(path))
        default: throw StoreFailure.profileAmbiguous(given, candidates)
        }
    }
}

struct Scope {
    let namespace: String?
    let profile: String?
    let project: Project?

    static let global = Scope(namespace: nil, profile: nil, project: nil)

    var qualifiedProfile: String? {
        guard let namespace, let profile else { return nil }
        return namespace + "/" + profile
    }

    var reference: String? {
        guard let namespace, let profile else { return nil }
        return namespace + "." + profile
    }

    func storedName(_ key: String) -> String {
        guard let qualifiedProfile else { return key }
        return qualifiedProfile + "/" + key
    }

    var profileArgument: String {
        guard let reference else { return "" }
        return "@" + reference + " "
    }

    var shownProfile: String {
        guard let profile else { return "@" }
        guard projectKeys != nil else { return "@" + (reference ?? profile) }
        return "@" + profile
    }

    var projectKeys: [String]? {
        guard let project, let profile, project.namespace == namespace else { return nil }
        return project.keys(for: profile)
    }
}

func isValidProfileName(_ name: String) -> Bool {
    guard !name.isEmpty else { return false }
    return name.allSatisfy { ($0.isASCII && ($0.isLetter || $0.isNumber)) || "_-".contains($0) }
}

enum ProfileArgument {
    case none
    case global
    case named(String)
    case qualified(namespace: String, profile: String)
}

func profileReference(_ argument: String) throws -> ProfileArgument {
    guard argument != "@" else { return .global }
    let parts = argument.dropFirst().split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    guard parts.count <= 2, parts.allSatisfy(isValidProfileName) else { throw StoreFailure.invalidProfileName(argument) }
    guard parts.count == 2 else { return .named(parts[0]) }
    return .qualified(namespace: parts[0], profile: parts[1])
}

func takeProfileArgument(_ arguments: [String]) throws -> (profile: ProfileArgument, rest: [String]) {
    guard let first = arguments.first, first.hasPrefix("@") else { return (.none, arguments) }
    return (try profileReference(first), Array(arguments.dropFirst()))
}

func scope(for chosen: ProfileArgument) throws -> Scope {
    switch chosen {
    case .global:
        return .global
    case .qualified(let namespace, let profile):
        guard let project = try locateProject(), project.namespace == namespace else {
            return Scope(namespace: namespace, profile: profile, project: nil)
        }
        return Scope(namespace: namespace, profile: try project.profile(matching: profile), project: project)
    case .named(let name):
        guard let project = try locateProject() else { throw StoreFailure.profileNeedsNamespace(name) }
        return Scope(namespace: project.namespace, profile: try project.profile(matching: name), project: project)
    case .none:
        let project = try locateProject()
        return Scope(namespace: project?.namespace, profile: project?.defaultProfile, project: project)
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

private func rejectingDuplicates(_ blocks: [Block], in shown: String) throws {
    var seen: [String: Set<String>] = [:]
    for block in blocks {
        for profile in block.profiles {
            for name in block.keys {
                guard seen[profile, default: []].insert(name).inserted else {
                    throw StoreFailure.badProjectFile(shown, "\(name) is listed twice for @\(profile)")
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
    func closeBlock() {
        if let open = profiles { blocks.append(Block(profiles: open, keys: keys)) }
        keys = []
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
                throw StoreFailure.badProjectFile(shown, "\(line) is not a namespace line: +name, with letters, digits, _ -")
            }
            namespace = name
            continue
        }
        guard namespace != nil else {
            throw StoreFailure.badProjectFile(shown, "\(line) comes before the +namespace line; the first line names the project, +foo")
        }
        if line.hasPrefix("@") {
            closeBlock()
            profiles = try parseProfileLine(line, in: shown)
            continue
        }
        guard profiles != nil else {
            throw StoreFailure.badProjectFile(shown, "\(line) comes before any @profile line; a project's keys live in a named profile")
        }
        guard isValidKey(line) else {
            throw StoreFailure.badProjectFile(shown, "\(line) is not a key (an environment variable name)")
        }
        keys.append(line)
    }
    closeBlock()
    guard let namespace else {
        throw StoreFailure.badProjectFile(shown, "no +namespace line; the first line names the project, +foo")
    }
    guard !blocks.isEmpty else {
        throw StoreFailure.badProjectFile(shown, "no @profile line; a project's keys live in a named profile")
    }
    try rejectingDuplicates(blocks, in: shown)
    return Project(directory: directory, namespace: namespace, blocks: blocks)
}

func storedKeysInScope(_ scope: Scope) throws -> [String] {
    let stored = try secretStore.storedKeys()
    guard let qualifiedProfile = scope.qualifiedProfile else { return stored.filter { !$0.contains("/") } }
    let prefix = qualifiedProfile + "/"
    return stored.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
}

func keysInScope(_ scope: Scope) throws -> [String] {
    if let keys = scope.projectKeys { return keys }
    return try storedKeysInScope(scope)
}
