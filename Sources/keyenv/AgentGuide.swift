let agentGuide = """
keyenv for an automated caller

A value stored here must never enter your context or your transcript. Anything
you read stays in both, and a keyring cannot take it back.

Do not run keyenv get. Its entire output is the secret.

To see what exists, read the names with keyenv list, and their shape with
keyenv preview:

  $ keyenv preview
  GITHUB_TOKEN        gh...f 40
  OPENROUTER_API_KEY  sk...2 73

Preview shows at most the first \(previewLeadingCharacters) and the last
\(previewTrailingCharacters) characters, and only while at least
\(previewMinimumHiddenCharacters) of them stay hidden. A value shorter than
that shows its length alone.

To hand a secret to a command, let the shell read it, so the value goes from
the keyring to that process without passing through you:

  OPENROUTER_API_KEY="$(keyenv get OPENROUTER_API_KEY)" ./run-eval

To store a secret, ask the person to run keyenv set <NAME> themselves. Typing
it for them puts it in your context first.

To check that it arrived, run keyenv preview <NAME> and compare the length
against what issued the secret. That confirms the value without reading it.
"""
