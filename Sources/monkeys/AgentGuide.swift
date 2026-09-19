private func wrapped(_ text: String, at width: Int = 78) -> String {
    var lines: [String] = []
    var line = ""
    for word in text.split(whereSeparator: \.isWhitespace) {
        if line.isEmpty {
            line = String(word)
        } else if line.count + 1 + word.count <= width {
            line += " " + word
        } else {
            lines.append(line)
            line = String(word)
        }
    }
    if !line.isEmpty { lines.append(line) }
    return lines.joined(separator: "\n")
}

private let maskingRule = wrapped("""
Preview shows at most the first \(previewLeadingCharacters) and the last
\(previewTrailingCharacters) characters, and only while at least
\(previewMinimumHiddenCharacters) of them stay hidden. A value shorter than that
shows its length alone.
""")

var styledAgentGuide: String {
    let lines = agentGuide.split(separator: "\n", omittingEmptySubsequences: false)
    return lines.enumerated().map { position, line in
        if position == 0 { return outputStyle(String(line), .bold, .brand) }
        guard line.hasPrefix("  ") else { return String(line) }
        return "  " + outputStyle(String(line.dropFirst(2)), .argument)
    }.joined(separator: "\n")
}

private let agentGuide = """
monkeys for an automated caller

A value stored here must never enter your context or your transcript. Anything
you read stays in both, and a keyring cannot take it back. There is no command
that prints a stored value, so the only thing to get right is how you spend it.

monkeys run puts the values you name into one command's environment and nowhere
else:

  monkeys run OPENROUTER_API_KEY -- ./bench

Nothing you write there holds the secret, so nothing you write can spill it.
With every name stored, run replaces itself with the command, so the exit
status, the output and the signals are the command's own.

A name that is not stored stops the run before it starts, and says what to ask
for:

  monkeys: ANTHROPIC_API_KEY is not stored yet
  nothing ran. ask the person to store it, then try again:
    monkeys set ANTHROPIC_API_KEY

Pass that on. Storing a secret is the person's move, not yours: typing one for
them puts it in your context before it reaches the keyring.

To see what exists, read the names with monkeys list, and their shape with
monkeys preview:

  $ monkeys preview
  GITHUB_TOKEN        gh...f 40
  OPENROUTER_API_KEY  sk...2 73

\(maskingRule)

A length and a two-character prefix confirm that the right value arrived
without reading it.

monkeys export prints every value as shell assignments, for a startup file to
eval. Never run it yourself, and never print a variable that already holds a
secret. Each of these puts a value in front of you:

  monkeys export
  echo "$OPENROUTER_API_KEY"
  env
  printenv

So does writing one into a file, a log, a commit, or a bug report. Where a
config file wants the secret, write whatever reference its format offers, such
as ${OPENROUTER_API_KEY}, and let the program expand it.
"""
