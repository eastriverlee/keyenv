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
    let names: [String]
}

struct Project {
    let directory: String
    let blocks: [Block]

    var path: String { directory + "/" + projectFileName }

    var profiles: [String] {
        var seen: [String] = []
        for profile in blocks.flatMap(\.profiles) where !seen.contains(profile) { seen.append(profile) }
        return seen
    }

    var defaultProfile: String { profiles[0] }

    func names(for profile: String) -> [String] {
        blocks.filter { $0.profiles.contains(profile) }.flatMap(\.names)
    }
}

struct Scope {
    let profile: String?
    let project: Project?

    func storedName(_ variable: String) -> String {
        guard let profile else { return variable }
        return profile + "/" + variable
    }

    var profileArgument: String {
        guard let profile else { return "" }
        return "@" + profile + " "
    }

    var projectNames: [String]? {
        guard let project, let profile else { return nil }
        return project.names(for: profile)
    }
}

func isValidProfileName(_ name: String) -> Bool {
    guard !name.isEmpty else { return false }
    return name.allSatisfy { ($0.isASCII && ($0.isLetter || $0.isNumber)) || "_-.".contains($0) }
}

enum ProfileArgument {
    case none
    case personal
    case named(String)
}

func takeProfileArgument(_ arguments: [String]) throws -> (profile: ProfileArgument, rest: [String]) {
    guard let first = arguments.first, first.hasPrefix("@") else { return (.none, arguments) }
    let rest = Array(arguments.dropFirst())
    guard first != "@" else { return (.personal, rest) }
    let name = String(first.dropFirst())
    guard isValidProfileName(name) else { throw StoreFailure.invalidProfileName(first) }
    return (.named(name), rest)
}

func resolveScope(_ arguments: [String]) throws -> (scope: Scope, rest: [String]) {
    let (chosen, rest) = try takeProfileArgument(arguments)
    switch chosen {
    case .personal:
        return (Scope(profile: nil, project: nil), rest)
    case .named(let name):
        let project = try locateProject()
        if let project, !project.profiles.contains(name) {
            throw StoreFailure.profileNotDeclared(name, project.profiles, abbreviatingHome(project.path))
        }
        return (Scope(profile: name, project: project), rest)
    case .none:
        let project = try locateProject()
        return (Scope(profile: project?.defaultProfile, project: project), rest)
    }
}

func locateProject() throws -> Project? {
    var directory = FileManager.default.currentDirectoryPath
    while true {
        let path = directory + "/" + projectFileName
        if FileManager.default.fileExists(atPath: path) {
            return try parseProject(at: path, directory: directory)
        }
        guard directory != "/" else { return nil }
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
            for name in block.names {
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
    var blocks: [Block] = []
    var profiles: [String]?
    var names: [String] = []
    func closeBlock() {
        if let open = profiles { blocks.append(Block(profiles: open, names: names)) }
        names = []
    }
    for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }
        if line.hasPrefix("@") {
            closeBlock()
            profiles = try parseProfileLine(line, in: shown)
            continue
        }
        guard profiles != nil else {
            throw StoreFailure.badProjectFile(shown, "\(line) comes before any @profile line; a project's names live in a named profile")
        }
        guard isValidVariableName(line) else {
            throw StoreFailure.badProjectFile(shown, "\(line) is not an environment variable name")
        }
        names.append(line)
    }
    closeBlock()
    guard !blocks.isEmpty else {
        throw StoreFailure.badProjectFile(shown, "no @profile line; a project's names live in a named profile")
    }
    try rejectingDuplicates(blocks, in: shown)
    return Project(directory: directory, blocks: blocks)
}

func storedNamesInScope(_ scope: Scope) throws -> [String] {
    let stored = try secretStore.storedNames()
    guard let profile = scope.profile else { return stored.filter { !$0.contains("/") } }
    let prefix = profile + "/"
    return stored.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
}

func namesInScope(_ scope: Scope) throws -> [String] {
    if let names = scope.projectNames { return names }
    return try storedNamesInScope(scope)
}
