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

struct Project {
    let directory: String
    let profile: String
    let names: [String]

    var path: String { directory + "/" + projectFileName }
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
        return (Scope(profile: name, project: try locateProject()), rest)
    case .none:
        let project = try locateProject()
        return (Scope(profile: project?.profile, project: project), rest)
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

func parseProject(at path: String, directory: String) throws -> Project {
    let contents = try String(contentsOfFile: path, encoding: .utf8)
    let shown = abbreviatingHome(path)
    var profile: String?
    var names: [String] = []
    for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }
        if line.hasPrefix("@") {
            let candidate = String(line.dropFirst())
            guard isValidProfileName(candidate) else {
                throw StoreFailure.badProjectFile(shown, "\(line) is not a profile name")
            }
            guard profile == nil else {
                throw StoreFailure.badProjectFile(shown, "a second profile, \(line)")
            }
            profile = candidate
            continue
        }
        guard isValidVariableName(line) else {
            throw StoreFailure.badProjectFile(shown, "\(line) is not an environment variable name")
        }
        guard !names.contains(line) else {
            throw StoreFailure.badProjectFile(shown, "\(line) is listed twice")
        }
        names.append(line)
    }
    guard let profile else {
        throw StoreFailure.badProjectFile(shown, "no @profile line; a project's names live in a named profile")
    }
    return Project(directory: directory, profile: profile, names: names)
}

func storedNamesInScope(_ scope: Scope) throws -> [String] {
    let stored = try secretStore.storedNames()
    guard let profile = scope.profile else { return stored.filter { !$0.contains("/") } }
    let prefix = profile + "/"
    return stored.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
}

func namesInScope(_ scope: Scope) throws -> [String] {
    if let project = scope.project { return project.names }
    return try storedNamesInScope(scope)
}
