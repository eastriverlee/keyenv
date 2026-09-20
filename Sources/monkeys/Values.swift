import Foundation


struct ValueEntry {
    let key: String
    let value: String
}

struct ValueBlock {
    let profiles: [String]
    let entries: [ValueEntry]
}

func spentValues(of project: Project?, for profile: String?) -> [SpentValue] {
    guard let project, let profile else { return [] }
    return project.values(for: profile).map { SpentValue(name: $0.key, value: $0.value) }
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
        guard open.contains(profile), let found = splitValueLine(trimmed), found.key == key else { continue }
        return ValueLineLocation(index: index, profiles: open)
    }
    return nil
}

private func rejectingSharedBlock(_ location: ValueLineLocation, _ key: String, _ profile: String, _ project: Project) throws {
    guard location.profiles.count > 1 else { return }
    let shown = location.profiles.map { "@" + project.shortName($0) }.joined(separator: ",")
    throw StoreFailure.bundleFailed("\(key) is set for \(shown) together in \(projectFileName); split that block by hand to change it for @\(project.shortName(profile)) alone")
}

private func fileLines(at path: String) throws -> [String] {
    let contents = try String(contentsOfFile: path, encoding: .utf8)
    var lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    if lines.last == "" { lines.removeLast() }
    return lines
}

private func writeLines(_ lines: [String], to path: String) throws {
    try (lines.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
}

func writeValue(_ value: String, forKey key: String, profile: String, in project: Project) throws {
    try writeValue(value, forKey: key, profile: profile, block: [profile], in: project)
}

func writeValue(_ value: String, forKey key: String, profile: String, block profiles: [String], in project: Project) throws {
    var lines = try fileLines(at: project.path)
    let line = key + "=" + value
    if let location = locate(key, for: profile, in: lines, of: project) {
        try rejectingSharedBlock(location, key, profile, project)
        lines[location.index] = line
    } else if let block = lines.lastIndex(of: profileLine(profiles, in: project.namespace)) {
        var end = block + 1
        while end < lines.count, !lines[end].trimmingCharacters(in: .whitespaces).hasPrefix("@") { end += 1 }
        while end > block + 1, lines[end - 1].trimmingCharacters(in: .whitespaces).isEmpty { end -= 1 }
        lines.insert(line, at: end)
    } else {
        lines += [profileLine(profiles, in: project.namespace), line]
    }
    try writeLines(lines, to: project.path)
}

func removeValue(forKey key: String, profile: String, in project: Project) throws -> Bool {
    var lines = try fileLines(at: project.path)
    guard let location = locate(key, for: profile, in: lines, of: project) else { return false }
    try rejectingSharedBlock(location, key, profile, project)
    lines.remove(at: location.index)
    try writeLines(lines, to: project.path)
    return true
}
