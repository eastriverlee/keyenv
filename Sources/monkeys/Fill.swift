import Foundation

private let fillForm = "monkeys fill @profile --with @profile"

private func label(_ scope: Scope) -> String {
    "@" + (scope.profile ?? "")
}

private func fillScopes(_ arguments: [String]) throws -> (source: Scope, target: Scope) {
    guard arguments.count == 3, arguments[1] == "--with",
          arguments[0].hasPrefix("@"), arguments[2].hasPrefix("@") else {
        throw StoreFailure.badInvocation(fillForm)
    }
    let (target, targetRest) = try resolveScope([arguments[0]])
    let (source, sourceRest) = try resolveScope([arguments[2]])
    guard sourceRest.isEmpty, targetRest.isEmpty else { throw StoreFailure.badInvocation(fillForm) }
    guard source.profile != target.profile else {
        throw StoreFailure.badInvocation(fillForm + ", with two different profiles")
    }
    return (source, target)
}

func runFill(_ arguments: [String]) throws {
    let (source, target) = try fillScopes(arguments)
    let stored = try secretStore.storedNames()
    let present = Set(stored)
    let considered = try target.projectNames ?? storedNamesInScope(source)
    let lacking = considered.filter { !present.contains(target.storedName($0)) }
    let filled = lacking.filter { present.contains(source.storedName($0)) }
    let stillMissing = lacking.filter { !present.contains(source.storedName($0)) }
    let kept = considered.count - lacking.count

    for name in filled {
        let value = try secretStore.read(forName: source.storedName(name))
        try secretStore.store(value, forName: target.storedName(name))
    }

    if filled.isEmpty {
        printToStandardError(messageStyle("nothing to fill", .dim) + " in \(label(target)) from \(label(source))")
    } else {
        let names = filled.map { messageStyle($0, .bold) }.joined(separator: ", ")
        printToStandardError(messageStyle("filled", .good) + " \(label(target)) from \(label(source)): " + names)
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
