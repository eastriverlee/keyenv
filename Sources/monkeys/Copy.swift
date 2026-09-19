import Foundation

private let copyForm = "monkeys copy @profile --to @profile"

private func label(_ scope: Scope) -> String {
    "@" + (scope.profile ?? "")
}

private func copyScopes(_ arguments: [String]) throws -> (source: Scope, target: Scope) {
    guard arguments.count == 3, arguments[1] == "--to",
          arguments[0].hasPrefix("@"), arguments[2].hasPrefix("@") else {
        throw StoreFailure.badInvocation(copyForm)
    }
    let (source, sourceRest) = try resolveScope([arguments[0]])
    let (target, targetRest) = try resolveScope([arguments[2]])
    guard sourceRest.isEmpty, targetRest.isEmpty else { throw StoreFailure.badInvocation(copyForm) }
    guard source.profile != target.profile else {
        throw StoreFailure.badInvocation(copyForm + ", with two different profiles")
    }
    return (source, target)
}

func runCopy(_ arguments: [String]) throws {
    let (source, target) = try copyScopes(arguments)
    let stored = try secretStore.storedNames()
    let present = Set(stored)
    let considered = try target.projectNames ?? storedNamesInScope(source)
    let lacking = considered.filter { !present.contains(target.storedName($0)) }
    let copied = lacking.filter { present.contains(source.storedName($0)) }
    let stillMissing = lacking.filter { !present.contains(source.storedName($0)) }
    let kept = considered.count - lacking.count

    for name in copied {
        let value = try secretStore.read(forName: source.storedName(name))
        try secretStore.store(value, forName: target.storedName(name))
    }

    if copied.isEmpty {
        printToStandardError(messageStyle("nothing to copy", .dim) + " from \(label(source)) to \(label(target))")
    } else {
        let names = copied.map { messageStyle($0, .bold) }.joined(separator: ", ")
        printToStandardError(messageStyle("copied", .good) + " to \(label(target)) from \(label(source)): " + names)
    }
    if kept > 0 {
        printToStandardError(messageStyle("kept", .dim) + " \(kept) \(label(target)) already had")
    }
    guard stillMissing.isEmpty else {
        let names = stillMissing.map { messageStyle($0, .bold) }.joined(separator: ", ")
        printToStandardError(messageStyle("still missing", .bad) + " in \(label(target)): " + names)
        exit(1)
    }
}
