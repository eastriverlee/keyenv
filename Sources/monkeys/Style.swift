import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

enum Style: String {
    case reset = "\u{1B}[0m"
    case bold = "\u{1B}[1m"
    case dim = "\u{1B}[2m"
    case brand = "\u{1B}[38;5;202m"
    case argument = "\u{1B}[36m"
    case good = "\u{1B}[32m"
    case bad = "\u{1B}[31m"
}

struct Painter: Sendable {
    let isEnabled: Bool

    func callAsFunction(_ text: String, _ styles: Style...) -> String {
        guard isEnabled, !text.isEmpty else { return text }
        return styles.map(\.rawValue).joined() + text + Style.reset.rawValue
    }
}

private func colorIsAllowed(on descriptor: Int32) -> Bool {
    let environment = ProcessInfo.processInfo.environment
    if environment["NO_COLOR"] != nil { return false }
    if environment["TERM"] == "dumb" { return false }
    return isatty(descriptor) != 0
}

let outputStyle = Painter(isEnabled: colorIsAllowed(on: STDOUT_FILENO))
let messageStyle = Painter(isEnabled: colorIsAllowed(on: STDERR_FILENO))
