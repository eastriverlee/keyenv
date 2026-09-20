import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

private let dotenvName = ".env"
private let exampleSuffixes = ["example", "sample", "template"]

struct DotenvFile {
    let name: String
    let path: String
    let profileName: String?
    let entries: [ValueEntry]
}

private enum Destination {
    case secret
    case value
}

private struct Choice {
    let key: String
    let profile: String
    let value: String
    let destination: Destination
}

private struct Kept {
    let key: String
    let profile: String
    let reason: String
}

private func isDotenvName(_ name: String) -> Bool {
    guard name.hasPrefix(dotenvName) else { return false }
    let suffix = name.dropFirst(dotenvName.count)
    if suffix.isEmpty { return true }
    guard suffix.hasPrefix("."), suffix.count > 1 else { return false }
    let rest = String(suffix.dropFirst())
    return isValidProfileName(rest) && !exampleSuffixes.contains(rest)
}

private func profileName(of fileName: String) -> String? {
    let suffix = String(fileName.dropFirst(dotenvName.count + 1))
    return suffix.isEmpty || suffix == "local" ? nil : suffix
}

private func dotenvNames(in directory: String) throws -> [String] {
    let names = try FileManager.default.contentsOfDirectory(atPath: directory).filter(isDotenvName)
    let leading = [dotenvName, dotenvName + ".local"].filter(names.contains)
    return leading + names.filter { !leading.contains($0) }.sorted()
}

private func unquoted(_ raw: String, at place: String) throws -> String {
    let value = raw.trimmingCharacters(in: .whitespaces)
    for quote in ["\"", "'"] where value.hasPrefix(quote) {
        guard value.count >= 2, value.hasSuffix(quote) else {
            throw StoreFailure.badDotenvLine(place, "the quote never closes; a value that spans lines has no place in \(projectFileName)")
        }
        return String(value.dropFirst().dropLast())
    }
    guard !value.contains(" #") else {
        throw StoreFailure.badDotenvLine(place, "a comment after the value is ambiguous; quote the value or drop the comment")
    }
    return value
}

private func parsedDotenvLine(_ line: String, at place: String) throws -> ValueEntry? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty || trimmed.hasPrefix("#") { return nil }
    let assignment = trimmed.hasPrefix("export ") ? String(trimmed.dropFirst("export ".count)) : trimmed
    guard let equals = assignment.firstIndex(of: "=") else {
        throw StoreFailure.badDotenvLine(place, "\(trimmed) is not KEY=value")
    }
    let key = assignment[..<equals].trimmingCharacters(in: .whitespaces)
    guard isValidKey(key) else {
        throw StoreFailure.badDotenvLine(place, "\(key) is not a key (an environment variable name)")
    }
    let value = try unquoted(String(assignment[assignment.index(after: equals)...]), at: place)
    guard !value.contains("${") else {
        throw StoreFailure.badDotenvLine(place, "\(key) expands another variable; monkeys keeps a value as it is")
    }
    return ValueEntry(key: key, value: value)
}

private func parsedDotenv(named name: String, in directory: String) throws -> DotenvFile {
    let path = directory + "/" + name
    let contents = try String(contentsOfFile: path, encoding: .utf8)
    var entries: [ValueEntry] = []
    for (index, line) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
        if let entry = try parsedDotenvLine(String(line), at: "\(name):\(index + 1)") { entries.append(entry) }
    }
    return DotenvFile(name: name, path: path, profileName: profileName(of: name), entries: entries)
}

private func readAnswer(_ prompt: String) -> String {
    FileHandle.standardError.write(Data(prompt.utf8))
    return (readLine(strippingNewline: true) ?? "").trimmingCharacters(in: .whitespaces)
}

private func askedDestination(for key: String, in profiles: [String]) -> Destination {
    let shown = profiles.map { "@" + $0 }.joined(separator: ",")
    while true {
        let answer = readAnswer(messageStyle(key, .bold) + " \(shown)  " + messageStyle("[s]ecret or [p]ublic?", .dim) + " ").lowercased()
        if answer.isEmpty || answer == "s" || answer == "secret" { return .secret }
        if answer == "p" || answer == "public" { return .value }
    }
}

private func askedDefaultProfile() -> String {
    let answer = readAnswer("Profile for \(dotenvName) " + messageStyle("[test]", .bold) + ": ")
    return answer.isEmpty ? "test" : answer
}

private func askedNamespace() -> String? {
    let answer = readAnswer("Namespace, +name " + messageStyle("(Enter for none)", .dim) + ": ")
    return answer.isEmpty ? nil : String(answer.drop(while: { $0 == "+" }))
}

private func rejectingNames(_ defaultProfile: String, _ namespace: String?, _ files: [DotenvFile]) throws {
    for name in [defaultProfile] + files.compactMap(\.profileName) where !isValidProfileName(name) {
        throw StoreFailure.invalidProfileName("@" + name)
    }
    if let namespace, !isValidProfileName(namespace) { throw StoreFailure.invalidProfileName("+" + namespace) }
}

private struct KeyOccurrence {
    var profiles: [String] = []
    var values: [String: String] = [:]
}

private func occurrences(in files: [DotenvFile], defaultProfile: String) -> [(key: String, occurrence: KeyOccurrence)] {
    var order: [String] = []
    var byKey: [String: KeyOccurrence] = [:]
    for file in files {
        let profile = file.profileName ?? defaultProfile
        for entry in file.entries {
            if byKey[entry.key] == nil { order.append(entry.key) }
            var occurrence = byKey[entry.key] ?? KeyOccurrence()
            if !occurrence.profiles.contains(profile) { occurrence.profiles.append(profile) }
            occurrence.values[profile] = entry.value
            byKey[entry.key] = occurrence
        }
    }
    return order.map { ($0, byKey[$0]!) }
}

private struct Existing {
    let project: Project?
    let stored: Set<String>

    func kind(of key: String, for fullProfile: String, shortProfile: String) -> (Destination, String)? {
        if stored.contains(fullProfile + "/" + key) { return (.secret, "already has a secret in @\(shortProfile)") }
        if let project, project.keys(for: fullProfile).contains(key) { return (.secret, "already a key of @\(shortProfile) in \(projectFileName)") }
        if let project, project.value(of: key, for: fullProfile) != nil { return (.value, "already a value in \(projectFileName) for @\(shortProfile)") }
        return nil
    }
}

private func decided(
    _ occurrences: [(key: String, occurrence: KeyOccurrence)],
    existing: Existing,
    namespace: String?,
    publicKeys: Set<String>?
) -> (choices: [Choice], kept: [Kept]) {
    var choices: [Choice] = []
    var kept: [Kept] = []
    for (key, occurrence) in occurrences {
        let destination =
            publicKeys.map { $0.contains(key) ? Destination.value : .secret }
            ?? askedDestination(for: key, in: occurrence.profiles)
        for profile in occurrence.profiles {
            let value = occurrence.values[profile]!
            let full = prefixed(profile, with: namespace)
            if let (kind, reason) = existing.kind(of: key, for: full, shortProfile: profile) {
                guard kind == destination else {
                    kept.append(Kept(key: key, profile: profile, reason: reason))
                    continue
                }
                let replaces =
                    publicKeys == nil
                    && askYesOrNo("  " + messageStyle(key, .bold) + " " + reason + "; replace it?")
                guard replaces else {
                    kept.append(Kept(key: key, profile: profile, reason: reason))
                    continue
                }
            }
            if destination == .value {
                printToStandardError("  " + messageStyle("public", .good) + " " + messageStyle(key + "=" + value, .bold) + " for @\(profile), into \(projectFileName)")
            }
            choices.append(Choice(key: key, profile: full, value: value, destination: destination))
        }
    }
    return (choices, kept)
}

private func secretBlocks(_ choices: [Choice], profiles: [String]) -> [Block] {
    var order: [[String]] = []
    var keysByProfiles: [[String]: [String]] = [:]
    var seen: [String: [String]] = [:]
    for choice in choices where choice.destination == .secret {
        seen[choice.key, default: []].append(choice.profile)
    }
    for choice in choices where choice.destination == .secret {
        let group = seen[choice.key]!
        guard !(keysByProfiles[group] ?? []).contains(choice.key) else { continue }
        if keysByProfiles[group] == nil { order.append(group) }
        keysByProfiles[group, default: []].append(choice.key)
    }
    let declared = Set(order.flatMap { $0 })
    let bare = profiles.filter { !declared.contains($0) }.map { Block(profiles: [$0], keys: []) }
    return order.map { Block(profiles: $0, keys: keysByProfiles[$0]!) } + bare
}

private func declaringMissingProfiles(_ profiles: [String], in directory: String) throws -> Project {
    let path = directory + "/" + projectFileName
    var project = try parseProject(at: path, directory: directory)
    let missing = profiles.filter { !project.profiles.contains($0) }
    guard !missing.isEmpty else { return project }
    let current = try String(contentsOfFile: path, encoding: .utf8)
    let separator = current.hasSuffix("\n") ? "" : "\n"
    let lines = missing.map { "@" + project.shortName($0) }.joined(separator: "\n") + "\n"
    try (current + separator + lines).write(toFile: path, atomically: true, encoding: .utf8)
    project = try parseProject(at: path, directory: directory)
    return project
}

private func reportGroups(_ label: String, _ style: Style, _ items: [(profile: String, key: String)]) {
    var order: [String] = []
    var byProfile: [String: [String]] = [:]
    for item in items {
        if byProfile[item.profile] == nil { order.append(item.profile) }
        byProfile[item.profile, default: []].append(item.key)
    }
    for profile in order {
        printToStandardError(messageStyle(label, style) + " @\(profile): " + byProfile[profile]!.map { messageStyle($0, .bold) }.joined(separator: ", "))
    }
}

private func removedFiles(_ files: [DotenvFile]) {
    var removed: [String] = []
    for file in files {
        guard unlink(file.path) == 0 else {
            printToStandardError(messageStyle("kept", .bad) + " \(file.name): \(String(cString: strerror(errno)))")
            continue
        }
        removed.append(file.name)
    }
    guard !removed.isEmpty else { return }
    printToStandardError(messageStyle("removed", .good) + " " + removed.map { messageStyle($0, .bold) }.joined(separator: ", "))
    printToStandardError("a .gitignore line for them is dead now and can go; monkeys leaves that file alone")
}

private let eatForm = "monkeys eat [+namespace] [@profile] [--public KEY[,KEY...]]"

private struct EatArguments {
    var namespace: String?
    var profile: String?
    var publicKeys: Set<String>?
}

private func eatArguments(_ arguments: [String]) throws -> EatArguments {
    var parsed = EatArguments()
    var rest = arguments[...]
    while let argument = rest.first {
        rest = rest.dropFirst()
        switch argument {
        case "--public":
            guard let list = rest.first else { throw StoreFailure.badInvocation(eatForm) }
            rest = rest.dropFirst()
            let keys = list.split(separator: ",").map(String.init)
            for key in keys where !isValidKey(key) { throw StoreFailure.invalidKey(key) }
            parsed.publicKeys = Set(keys)
        case let argument where argument.hasPrefix("+"):
            parsed.namespace = String(argument.dropFirst())
        case let argument where argument.hasPrefix("@"):
            parsed.profile = String(argument.dropFirst())
        default:
            throw StoreFailure.badInvocation(eatForm)
        }
    }
    return parsed
}

func runEat(_ arguments: [String]) throws {
    let given = try eatArguments(arguments)
    let here = FileManager.default.currentDirectoryPath
    let names = try dotenvNames(in: here)
    guard !names.isEmpty else {
        throw StoreFailure.bundleFailed("no \(dotenvName) file here; eat reads \(dotenvName), \(dotenvName).local and \(dotenvName).<profile> from the current directory")
    }
    let files = try names.map { try parsedDotenv(named: $0, in: here) }
    let asks = given.publicKeys == nil
    guard !asks || (isTerminal(STDIN_FILENO) && isTerminal(STDERR_FILENO)) else {
        throw StoreFailure.bundleFailed("eat asks a question per key, so it needs a terminal; name the public keys with --public KEY,KEY and it asks nothing")
    }
    let project = try locateProject()
    let directory = project?.directory ?? (gitRoot(above: here) ?? here)
    let namespace =
        given.namespace ?? project?.namespace ?? (asks ? askedNamespace() : nil)
    let defaultProfile =
        given.profile ?? project.map { $0.shortName($0.defaultProfile) }
        ?? (asks ? askedDefaultProfile() : "test")
    try rejectingNames(defaultProfile, namespace, files)
    let existing = Existing(project: project, stored: Set(try secretStore.storedKeys()))
    let (choices, kept) = decided(
        occurrences(in: files, defaultProfile: defaultProfile),
        existing: existing,
        namespace: namespace,
        publicKeys: given.publicKeys
    )
    let profiles = Array(Set(choices.map(\.profile))).sorted()
    try reconcileProjectFile(namespace: namespace, secretBlocks(choices, profiles: profiles), in: directory)
    let declared = try declaringMissingProfiles(profiles, in: directory)
    for choice in choices {
        switch choice.destination {
        case .secret: try secretStore.store(choice.value, forName: choice.profile + "/" + choice.key)
        case .value: try writeValue(choice.value, forKey: choice.key, profile: choice.profile, in: declared)
        }
    }
    reportGroups("remembered", .good, choices.filter { $0.destination == .secret }.map { (declared.shortName($0.profile), $0.key) })
    reportGroups("public", .good, choices.filter { $0.destination == .value }.map { (declared.shortName($0.profile), $0.key) })
    reportGroups("kept", .dim, kept.map { ($0.profile, $0.key) })
    removedFiles(files)
}
