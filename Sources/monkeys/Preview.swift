import Foundation

let previewLeadingCharacters = 2
let previewTrailingCharacters = 1
let previewMinimumHiddenCharacters = 5

private func printable(_ character: Character) -> Character {
    character.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) } ? character : "?"
}

func maskedValue(_ value: String) -> String {
    let count = value.count
    let revealed = previewLeadingCharacters + previewTrailingCharacters
    guard count >= revealed + previewMinimumHiddenCharacters else { return "... \(count)" }
    let leading = String(value.prefix(previewLeadingCharacters).map(printable))
    let trailing = String(value.suffix(previewTrailingCharacters).map(printable))
    return "\(leading)...\(trailing) \(count)"
}
