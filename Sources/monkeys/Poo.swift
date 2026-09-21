import Foundation

private let dotenvName = ".env"
private let header = "# monkeys' poo"
private let documentation = "https://monk3ys.dev/poo"

private func headerLine(for scope: Scope) -> String {
    let profile = scope.project?.profiles.count ?? 0 > 1 ? " " + scope.shownProfile : ""
    return header + profile + ". read " + documentation
}

private func pooLines(_ project: Project, _ profile: String) -> [String] {
    project.keys(for: profile) + project.values(for: profile).map { $0.key + "=" + $0.value }
}

private func refusesToOverwrite(_ path: String) throws -> Bool {
    guard FileManager.default.fileExists(atPath: path) else { return false }
    let existing = try String(contentsOfFile: path, encoding: .utf8)
    return !existing.hasPrefix(header)
}

private func counted(_ count: Int, _ word: String) -> String {
    "\(count) \(word)" + (count == 1 ? "" : "s")
}

func runPoo(_ arguments: [String]) throws {
    let (chosen, rest) = try takeProfileArgument(arguments)
    guard rest.isEmpty else {
        throw StoreFailure.bundleFailed("poo takes a profile and nothing else: monkeys poo @test")
    }
    let target = try scope(for: chosen)
    guard let project = target.project, let profile = target.profile, target.projectKeys != nil else {
        throw StoreFailure.bundleFailed(
            "poo writes the names a \(projectFileName) lists, and there is none here")
    }

    let path = project.directory + "/" + dotenvName
    if try refusesToOverwrite(path) {
        throw StoreFailure.bundleFailed(
            "\(abbreviatingHome(path)) was not written by poo: monkeys eat it first, or move it aside")
    }

    let lines = pooLines(project, profile)
    try ([headerLine(for: target)] + lines + [""]).joined(separator: "\n")
        .write(toFile: path, atomically: true, encoding: .utf8)

    let names = project.keys(for: profile).count
    let values = project.values(for: profile).count
    let carried = values == 0 ? counted(names, "name") : counted(names, "name") + ", " + counted(values, "value")
    printToStandardError(
        messageStyle("wrote", .good) + " " + messageStyle(dotenvName, .bold)
            + " for " + messageStyle(target.shownProfile, .argument) + ": " + carried)
    printHintToTerminal(
        messageStyle("the values stay in the vault; give them to a command with:", .dim) + "\n  "
            + messageStyle("monkeys run " + target.profileArgument + "<command>", .argument))
}
