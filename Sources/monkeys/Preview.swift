import Foundation

let previewLeadingCharacters = 2
let previewTrailingCharacters = 1
let previewMinimumHiddenCharacters = 5

private func printable(_ character: Character) -> Character {
    character.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) } ? character : "?"
}

func maskedValue(_ value: String) -> String {
    let count = value.count
    let length = outputStyle("\(count)", .dim)
    let revealed = previewLeadingCharacters + previewTrailingCharacters
    guard count >= revealed + previewMinimumHiddenCharacters else {
        return outputStyle("...", .dim) + " " + length
    }
    let leading = String(value.prefix(previewLeadingCharacters).map(printable))
    let trailing = String(value.suffix(previewTrailingCharacters).map(printable))
    return outputStyle(leading, .brand) + outputStyle("...", .dim)
        + outputStyle(trailing, .brand) + " " + length
}
