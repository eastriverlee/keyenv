import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

private let dotenvName = ".env"
private let header = "# monkeys' poo"
private let documentation = "https://monk3ys.dev/poo"
private let secretsFlag = "--WITH_SECRETS"
private let expandFlag = "--EXPAND_DANGEROUSLY"
private let openFlag = "--open"

private struct PooRequest {
    let reachesTheVault: Bool
    let expands: Bool
    let opens: Bool
    let directory: String?
}

private func takeFlags(_ arguments: [String]) throws -> (request: PooRequest, rest: [String]) {
    let (directory, given) = try takeDirectoryFlag(pathFlag, arguments)
    let reachesTheVault = given.contains(secretsFlag)
    let expands = given.contains(expandFlag)
    let opens = given.contains(openFlag)
    guard !expands || reachesTheVault else {
        throw StoreFailure.bundleFailed(
            "\(expandFlag) runs the lookups \(secretsFlag) writes, and writes none of its own")
    }
    guard !expands || (isTerminal(STDIN_FILENO) && isTerminal(STDERR_FILENO)) else {
        throw StoreFailure.bundleFailed(
            "\(expandFlag) leaves secrets in a file for a person to paste, so it needs a terminal")
    }
    return (PooRequest(reachesTheVault: reachesTheVault, expands: expands, opens: opens,
                       directory: directory),
            given.filter { $0 != secretsFlag && $0 != expandFlag && $0 != openFlag })
}

private func headerLine(_ scope: Scope, _ request: PooRequest) -> String {
    let profile = (scope.project?.profiles.count ?? 0) > 1 || request.reachesTheVault
        ? " " + scope.shownProfile : ""
    guard request.reachesTheVault else { return header + profile + ". read " + documentation }
    let kind = request.expands ? ", secrets in the open. delete this file" : ", vault lookups"
    return header + profile + kind + ". read " + documentation
}

private func dotenvQuoted(_ value: String, _ key: String) throws -> String {
    guard !value.contains("\""), !value.contains("\\") else {
        throw StoreFailure.bundleFailed(
            "\(key) holds a quote or a backslash, which no dotenv line carries back unchanged")
    }
    var written = ""
    for character in value {
        switch character {
        case "$": written += "\\$"
        case "\n": written += "\\n"
        case "\r": written += "\\r"
        default: written.append(character)
        }
    }
    return "\"" + written + "\""
}

private func valueLines(_ project: Project, _ profile: String) -> [String] {
    project.values(for: profile).map { $0.key + "=" + $0.value }
}

private func nameLines(_ project: Project, _ profile: String) -> [String] {
    project.keys(for: profile) + valueLines(project, profile)
}

private func lookupLines(_ project: Project, _ profile: String, _ scope: Scope) throws -> [String] {
    let keys = try storedOrRefused(project, profile, scope)
    return keys.map { $0 + "=\"$(" + vaultLookup(scope.storedName($0)) + ")\"" }
        + valueLines(project, profile)
}

private func openSecretLines(_ project: Project, _ profile: String, _ scope: Scope) throws -> [String] {
    let keys = try storedOrRefused(project, profile, scope)
    return try keys.map { $0 + "=" + (try dotenvQuoted(try secretStore.read(forName: scope.storedName($0)), $0)) }
        + valueLines(project, profile)
}

private func storedOrRefused(_ project: Project, _ profile: String, _ scope: Scope) throws -> [String] {
    let keys = project.keys(for: profile)
    let stored = Set(try secretStore.storedKeys())
    let missing = keys.filter { !stored.contains(scope.storedName($0)) }
    guard missing.isEmpty else { throw StoreFailure.keysNotStored(missing, scope.profileArgument) }
    return keys
}

private func madeTemporaryDirectory() throws -> String {
    var template = Array("/tmp/monkeys-XXXXXX".utf8CString)
    let made = template.withUnsafeMutableBufferPointer { buffer -> Bool in
        guard let start = buffer.baseAddress else { return false }
        return mkdtemp(start) != nil
    }
    guard made else { throw StoreFailure.bundleFailed("/tmp would not take a directory to write into") }
    return String(cString: template)
}

private func refusesToOverwrite(_ path: String) throws -> Bool {
    guard FileManager.default.fileExists(atPath: path) else { return false }
    return !(try String(contentsOfFile: path, encoding: .utf8)).hasPrefix(header)
}

private func counted(_ count: Int, _ word: String) -> String {
    "\(count) \(word)" + (count == 1 ? "" : "s")
}

private func written(_ lines: [String], to path: String) throws {
    try (lines + [""]).joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
}

private func tally(_ project: Project, _ profile: String, _ word: String) -> String {
    let keys = project.keys(for: profile).count
    let values = project.values(for: profile).count
    guard values > 0 else { return counted(keys, word) }
    return counted(keys, word) + ", " + counted(values, "value")
}

private func destination(_ request: PooRequest) throws -> String {
    guard let directory = request.directory else {
        return try madeTemporaryDirectory() + "/" + dotenvName
    }
    let path = URL(fileURLWithPath: directory).appendingPathComponent(dotenvName).path
    if try refusesToOverwrite(path) {
        throw StoreFailure.bundleFailed(
            "\(abbreviatingHome(path)) was not written by poo: monkeys eat it first, or move it aside")
    }
    let place = messageStyle(abbreviatingHome(path), .bold)
    guard request.expands else {
        try confirmedOutOfHarm(
            path, "a " + dotenvName + " into " + place + ", where a commit can take it. go ahead?")
        return path
    }
    try confirmedOutOfHarm(
        path,
        messageStyle("plain secrets into", .bad) + " " + place
            + ", where a commit can take them. not recommended.",
        understanding: true)
    return path
}

private func writeFile(
    _ project: Project, _ profile: String, _ scope: Scope, _ request: PooRequest, _ lines: [String]
) throws {
    let path = try destination(request)
    try written([headerLine(scope, request)] + lines, to: path)
    if request.expands {
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    }
    let word = request.expands ? "secret" : request.reachesTheVault ? "lookup" : "key"
    printToStandardError(
        messageStyle("wrote", .good) + " " + messageStyle(abbreviatingHome(path), .bold) + " for "
            + messageStyle(scope.shownProfile, .argument) + ": " + tally(project, profile, word))
    if request.expands {
        printToStandardError(
            messageStyle("the secrets are in the open in that file; delete it when the deploy is"
                + " done", .bad))
    }
    if request.opens { revealInFileManager(path) }
}

func runPoo(_ arguments: [String]) throws {
    let (request, positional) = try takeFlags(arguments)
    let (chosen, rest) = try takeProfileArgument(positional)
    guard rest.isEmpty else {
        throw StoreFailure.bundleFailed("poo takes a profile and nothing else: monkeys poo @test")
    }
    if request.reachesTheVault, case .named = chosen {} else if request.reachesTheVault {
        throw StoreFailure.bundleFailed(
            "\(secretsFlag) reaches one profile's own secrets, so name which:"
                + " monkeys poo @production \(secretsFlag)")
    }
    let target = try scope(for: chosen)
    guard let project = target.project, let profile = target.profile, target.projectKeys != nil else {
        throw StoreFailure.bundleFailed(
            "poo writes the names a \(projectFileName) lists, and there is none here")
    }

    guard request.reachesTheVault else {
        return try writeFile(project, profile, target, request, nameLines(project, profile))
    }
    guard request.expands else {
        return try writeFile(
            project, profile, target, request, try lookupLines(project, profile, target))
    }
    try writeFile(
        project, profile, target, request, try openSecretLines(project, profile, target))
}
