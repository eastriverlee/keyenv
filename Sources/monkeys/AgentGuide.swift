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

let agentGuide = """
monkeys for an automated caller

A value stored here must never enter your context or your transcript. Anything
you read stays in both, and a keyring cannot take it back.

Reach a secret as an environment variable, and only as one.

Never run monkeys get as a command of its own:

  monkeys get OPENROUTER_API_KEY

Its entire output is the secret, and whatever a command prints, you have read.

Inside another command the same call is right, because the shell performs the
substitution and hands the value to that process. What returns to you is only
what the process itself prints:

  OPENROUTER_API_KEY="$(monkeys get OPENROUTER_API_KEY)" ./run-eval

When a startup file already runs eval "$(monkeys export)", every shell you open
carries the variable, so name nothing and call nothing:

  ./run-eval

Never print a variable that holds a secret. Each of these puts the value in
front of you as surely as get does:

  echo "$OPENROUTER_API_KEY"
  env
  printenv

So does writing it into a file, a log, a commit, or a bug report. Where a
config file wants the secret, write whatever reference its format offers, such
as ${OPENROUTER_API_KEY}, and let the program expand it.

To see what exists, read the names with monkeys list, and their shape with
monkeys preview:

  $ monkeys preview
  GITHUB_TOKEN        gh...f 40
  OPENROUTER_API_KEY  sk...2 73

\(maskingRule)

To store a secret, ask the person to run monkeys set <NAME> themselves. Typing
it for them puts it in your context first.

To check that it arrived, run monkeys preview <NAME> and compare the length
against what issued the secret. That confirms the value without reading it.
"""
