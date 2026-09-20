import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

let walkForm = "monkeys remember [@profile] [--all]"

private enum WalkOutcome: String {
    case remembered
    case kept
    case skipped
}

private func readSecret(prompting prompt: String) -> String {
    guard let entered = getpass(prompt) else { return "" }
    return String(cString: entered)
}

private func walkPrompt(for key: String, keeping mask: String?) -> String {
    guard let mask else { return messageStyle(key, .bold) + ": " }
    return messageStyle(key, .bold) + " " + messageStyle("(", .dim) + mask + messageStyle(", Enter keeps)", .dim) + ": "
}

private func mark(_ isStored: Bool) -> String {
    isStored ? outputStyle("✓", .good) : outputStyle("✗", .bad)
}

private func printWalkSummary(_ scope: Scope, _ outcomes: [(key: String, outcome: WalkOutcome)]) {
    let label = scope.profile == scope.project?.defaultProfile ? outputStyle("  default", .dim) : ""
    print(outputStyle(scope.shownProfile, .bold) + label)
    for (key, outcome) in outcomes {
        print("  " + mark(outcome != .skipped) + " " + key + "  " + outputStyle(outcome.rawValue, .dim))
    }
}

func walkProfile(_ scope: Scope, walksAll: Bool) throws {
    guard let profile = scope.profile, let keys = scope.projectKeys else {
        throw StoreFailure.bundleFailed("a key is required here: monkeys remember <KEY>. remember walks a profile's keys only inside a project")
    }
    guard isTerminal(STDIN_FILENO) else {
        throw StoreFailure.bundleFailed("the walk reads each secret from the terminal; pipe one secret into monkeys remember <KEY> instead")
    }
    let stored = Set(try storedKeysInScope(scope))
    var outcomes: [(key: String, outcome: WalkOutcome)] = []
    for key in keys {
        let isStored = stored.contains(key)
        if isStored, !walksAll {
            outcomes.append((key, .kept))
            continue
        }
        let name = profile + "/" + key
        let mask = isStored ? maskedValue(try secretStore.read(forName: name), painted: messageStyle) : nil
        let entered = readSecret(prompting: walkPrompt(for: key, keeping: mask))
        guard !entered.isEmpty else {
            outcomes.append((key, isStored ? .kept : .skipped))
            continue
        }
        try secretStore.store(entered, forName: name)
        outcomes.append((key, .remembered))
    }
    printWalkSummary(scope, outcomes)
    guard outcomes.allSatisfy({ $0.outcome != .skipped }) else { exit(1) }
}
