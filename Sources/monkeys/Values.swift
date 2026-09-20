import Foundation

let valuesFileName = ".monvalues"

struct ValueEntry {
    let key: String
    let value: String
}

struct ValueBlock {
    let profiles: [String]
    let entries: [ValueEntry]
}

struct ProjectValues {
    let directory: String
    let blocks: [ValueBlock]

    var path: String { directory + "/" + valuesFileName }

    func entries(for profile: String) -> [ValueEntry] {
        blocks.filter { $0.profiles.contains(profile) }.flatMap(\.entries)
    }

    func value(of key: String, for profile: String) -> String? {
        entries(for: profile).first { $0.key == key }?.value
    }

    static func empty(in directory: String) -> ProjectValues {
        ProjectValues(directory: directory, blocks: [])
    }
}

func loadValues(of project: Project) throws -> ProjectValues {
    let path = project.directory + "/" + valuesFileName
    guard FileManager.default.fileExists(atPath: path) else { return .empty(in: project.directory) }
    return try parseValues(at: path, of: project)
}

private func splitValueLine(_ line: String) -> (key: String, value: String)? {
    guard let equals = line.firstIndex(of: "=") else { return nil }
    let key = String(line[..<equals])
    guard isValidKey(key) else { return nil }
    return (key, String(line[line.index(after: equals)...]))
}

func parseValues(at path: String, of project: Project) throws -> ProjectValues {
    let contents = try String(contentsOfFile: path, encoding: .utf8)
    let shown = abbreviatingHome(path)
    var blocks: [ValueBlock] = []
    var profiles: [String]?
    var entries: [ValueEntry] = []
    func closeBlock() {
        if let open = profiles { blocks.append(ValueBlock(profiles: open, entries: entries)) }
        entries = []
    }
    for (index, rawLine) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
        let line = String(rawLine)
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let number = index + 1
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
        if trimmed.hasPrefix("+") {
            throw StoreFailure.badValuesFile(shown, number, "\(trimmed): the namespace is the project's, so \(valuesFileName) has no + line")
        }
        if trimmed.hasPrefix("@") {
            closeBlock()
            profiles = try trimmed.dropFirst().split(separator: ",", omittingEmptySubsequences: false).map { piece in
                let name = piece.trimmingCharacters(in: .whitespaces)
                guard isValidProfileName(name) else {
                    throw StoreFailure.badValuesFile(shown, number, "\(trimmed) is not a profile line: @name or @name,name")
                }
                let full = prefixed(name, with: project.namespace)
                guard project.profiles.contains(full) else {
                    throw StoreFailure.badValuesFile(shown, number, "@\(name) is not a profile \(projectFileName) declares")
                }
                return full
            }
            continue
        }
        guard profiles != nil else {
            throw StoreFailure.badValuesFile(shown, number, "\(trimmed) comes before any @profile line")
        }
        guard let (key, value) = splitValueLine(line.drop(while: { $0 == " " || $0 == "\t" }).description) else {
            throw StoreFailure.badValuesFile(shown, number, "\(trimmed) is not KEY=value")
        }
        entries.append(ValueEntry(key: key, value: value))
    }
    closeBlock()
    let values = ProjectValues(directory: project.directory, blocks: blocks)
    try rejectingDuplicateValues(values, in: shown, namespace: project.namespace)
    return values
}

private func rejectingDuplicateValues(_ values: ProjectValues, in shown: String, namespace: String?) throws {
    var seen: [String: Set<String>] = [:]
    for block in values.blocks {
        for profile in block.profiles {
            for entry in block.entries {
                guard seen[profile, default: []].insert(entry.key).inserted else {
                    throw StoreFailure.badProjectFile(shown, "\(entry.key) is set twice for @\(shortened(profile, in: namespace))")
                }
            }
        }
    }
}

func sharedKeys(_ project: Project, _ values: ProjectValues, for profile: String) -> [String] {
    let listed = project.keys(for: profile)
    return values.entries(for: profile).map(\.key).filter(listed.contains)
}

func rejectingSharedKeys(_ project: Project, _ values: ProjectValues, for profile: String) throws {
    let shared = sharedKeys(project, values, for: profile)
    guard shared.isEmpty else {
        throw StoreFailure.keysInBothFiles(shared, project.shortName(profile))
    }
}

func spentValues(of project: Project?, for profile: String?) throws -> [SpentValue] {
    guard let project, let profile else { return [] }
    let values = try loadValues(of: project)
    try rejectingSharedKeys(project, values, for: profile)
    return values.entries(for: profile).map { SpentValue(name: $0.key, value: $0.value) }
}

private func profileLine(_ profiles: [String], in namespace: String?) -> String {
    "@" + profiles.map { shortened($0, in: namespace) }.joined(separator: ",")
}

private struct ValueLineLocation {
    let index: Int
    let profiles: [String]
}

private func locate(_ key: String, for profile: String, in lines: [String], of project: Project) -> ValueLineLocation? {
    var open: [String] = []
    for (index, line) in lines.enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("@") {
            open = trimmed.dropFirst().split(separator: ",").map { prefixed($0.trimmingCharacters(in: .whitespaces), with: project.namespace) }
            continue
        }
        guard open.contains(profile), let (found, _) = splitValueLine(trimmed), found == key else { continue }
        return ValueLineLocation(index: index, profiles: open)
    }
    return nil
}

private func rejectingSharedBlock(_ location: ValueLineLocation, _ key: String, _ profile: String, _ project: Project) throws {
    guard location.profiles.count > 1 else { return }
    let shown = location.profiles.map { "@" + project.shortName($0) }.joined(separator: ",")
    throw StoreFailure.bundleFailed("\(key) is set for \(shown) together in \(valuesFileName); split that block by hand to change it for @\(project.shortName(profile)) alone")
}

private func fileLines(at path: String) throws -> [String] {
    guard FileManager.default.fileExists(atPath: path) else { return [] }
    let contents = try String(contentsOfFile: path, encoding: .utf8)
    var lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    if lines.last == "" { lines.removeLast() }
    return lines
}

private func writeLines(_ lines: [String], to path: String) throws {
    try (lines.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
}

func writeValue(_ value: String, forKey key: String, profile: String, in project: Project) throws {
    let path = project.directory + "/" + valuesFileName
    var lines = try fileLines(at: path)
    let line = key + "=" + value
    if let location = locate(key, for: profile, in: lines, of: project) {
        try rejectingSharedBlock(location, key, profile, project)
        lines[location.index] = line
    } else if let block = lines.lastIndex(of: profileLine([profile], in: project.namespace)) {
        var end = block + 1
        while end < lines.count, !lines[end].trimmingCharacters(in: .whitespaces).hasPrefix("@") { end += 1 }
        while end > block + 1, lines[end - 1].trimmingCharacters(in: .whitespaces).isEmpty { end -= 1 }
        lines.insert(line, at: end)
    } else {
        lines += [profileLine([profile], in: project.namespace), line]
    }
    try writeLines(lines, to: path)
}

func removeValue(forKey key: String, profile: String, in project: Project) throws -> Bool {
    let path = project.directory + "/" + valuesFileName
    var lines = try fileLines(at: path)
    guard let location = locate(key, for: profile, in: lines, of: project) else { return false }
    try rejectingSharedBlock(location, key, profile, project)
    lines.remove(at: location.index)
    try writeLines(lines, to: path)
    return true
}

func valueBlockText(_ blocks: [ValueBlock], in namespace: String?) -> String {
    blocks.map { block in
        ([profileLine(block.profiles, in: namespace)] + block.entries.map { $0.key + "=" + $0.value }).joined(separator: "\n")
    }.joined(separator: "\n") + "\n"
}
