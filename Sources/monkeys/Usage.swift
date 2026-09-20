struct CommandSummary {
    let verb: String
    let arguments: String
    let summary: String
}

let commandSummaries = [
    CommandSummary(verb: "set", arguments: "<KEY>",
                   summary: "store a secret typed or piped in"),
    CommandSummary(verb: "list", arguments: "",
                   summary: "print every stored key"),
    CommandSummary(verb: "preview", arguments: "[KEY...]",
                   summary: "show each secret masked, with length"),
    CommandSummary(verb: "remove", arguments: "<KEY>",
                   summary: "delete one stored secret"),
    CommandSummary(verb: "run", arguments: "<KEY>[,<KEY>] <command>",
                   summary: "run a command with those secrets set"),
    CommandSummary(verb: "run", arguments: "--all <command>",
                   summary: "the same, with every stored secret"),
    CommandSummary(verb: "run", arguments: "--no-redact <command>",
                   summary: "the same, output untouched"),
    CommandSummary(verb: "run", arguments: "<command>",
                   summary: "the same, keys read from .monkeys"),
    CommandSummary(verb: "export", arguments: "[KEY...]",
                   summary: "vault lookups for a startup file"),
    CommandSummary(verb: "pack", arguments: "[name] [--only ...]",
                   summary: "one encrypted file of the profiles"),
    CommandSummary(verb: "unpack", arguments: "<name> [dir] [--keep]",
                   summary: "store its secrets, write its .monkeys"),
    CommandSummary(verb: "fill", arguments: "@a --with @b",
                   summary: "give @a the keys it lacks, from @b"),
    CommandSummary(verb: "doctor", arguments: "[--short]",
                   summary: "what each profile has and lacks"),
]

private func plainInvocation(_ command: CommandSummary) -> String {
    command.arguments.isEmpty
        ? "monkeys \(command.verb)"
        : "monkeys \(command.verb) \(command.arguments)"
}

private func paintedInvocation(_ command: CommandSummary) -> String {
    let start = outputStyle("monkeys", .dim) + " " + outputStyle(command.verb, .bold)
    guard !command.arguments.isEmpty else { return start }
    return start + " " + outputStyle(command.arguments, .argument)
}

private var commandLines: [String] {
    let width = commandSummaries.map { plainInvocation($0).count }.max() ?? 0
    return commandSummaries.map { command in
        let gap = String(repeating: " ", count: width - plainInvocation(command).count + 2)
        return "  " + paintedInvocation(command) + gap + command.summary
    }
}

var usage: String {
    """
    \(outputStyle("monkeys", .bold, .brand)) - a cross-platform .env alternative for the LLM era

    \(commandLines.joined(separator: "\n"))

    Spend a secret on one command:

      \(outputStyle("monkeys run OPENROUTER_API_KEY ./hello.sh", .argument))

    A project keeps its keys in \(projectFileName), under the profile they live in:

      \(outputStyle("@foo", .argument))
      \(outputStyle("DATABASE_URL", .argument))
      \(outputStyle("STRIPE_SECRET_KEY", .argument))

    In that directory or below it within the checkout, run takes only the
    command, and set, preview
    and remove read and write that profile:

      \(outputStyle("monkeys run ./hello.sh", .argument))
      \(outputStyle("monkeys set STRIPE_SECRET_KEY", .argument))        stored as foo/STRIPE_SECRET_KEY

    A profile line can name several profiles, and a file can have several
    blocks. Each profile gets the keys of every block that lists it; the first
    profile in the file is the one run uses when none is given:

      \(outputStyle("@test.foo,foo", .argument))
      \(outputStyle("DATABASE_URL", .argument))
      \(outputStyle("@foo", .argument))
      \(outputStyle("SENTRY_DSN", .argument))

      \(outputStyle("monkeys run @foo ./deploy", .argument))
      \(outputStyle("monkeys doctor", .argument))                     which profile lacks what

    A profile that shares most of its secrets with another is filled from it.
    fill moves only the keys the target lacks, never a secret it already
    holds, and says which keys moved:

      \(outputStyle("monkeys fill @foo --with @test.foo", .argument))

    A leading @profile picks another declared profile, and a prefix that fits
    only one of them is enough:

      \(outputStyle("monkeys set @foo SENTRY_DSN", .argument))      stored as foo/SENTRY_DSN

    A key stored outside any project has no profile and needs no @; those
    are the global keys. Inside a project every command is scoped to its
    profile, so a bare @ says no profile: it sets the file aside, keys are
    given again, and the global keys are reached without leaving the
    directory:

      \(outputStyle("monkeys run TYPESAFE_API_KEY claude", .argument))     outside a project
      \(outputStyle("monkeys run @ TYPESAFE_API_KEY claude", .argument))   inside one, the same secret

    For a shell that should carry secrets from startup, export writes the lines
    to paste into your startup file yourself. Each asks this machine's vault
    for one secret when the shell starts; none of them holds one:

      \(outputStyle("monkeys export TYPESAFE_API_KEY", .argument))
      \(outputStyle("monkeys export", .argument))                the project's keys

    Share the project's profiles as one encrypted file: every profile the
    file declares and every key, unless --only says which. After it, a
    @profile (or @a,b, several at once) opens a block and the keys after
    it belong to every profile in that block, the way the file is written;
    keys with no @ before them come from the default profile, the first
    the file mentions. The bundle keeps that shape, and unpack writes it
    back as the project file. The file is named after the first profile it
    carries unless you name it, before --only.
    pack asks for a passphrase; unpack asks again, stores the secrets,
    writes the keys into .monkeys at the root of the git checkout you are
    in, here when there is none, or in the directory you name, and deletes
    the bundle, since it has done its job; --keep leaves it:

      \(outputStyle("monkeys pack", .argument))                   writes test.foo.monkeys
      \(outputStyle("monkeys pack --only @foo", .argument))       writes foo.monkeys
      \(outputStyle("monkeys pack --only OPENROUTER_API_KEY", .argument))
      \(outputStyle("monkeys pack --only @test.foo,foo OPENROUTER_API_KEY", .argument))
      \(outputStyle("monkeys pack shared --only @test.foo @foo SENTRY_DSN", .argument))
      \(outputStyle("monkeys unpack test.foo", .argument))

    \(styledAgentGuide)
    """
}
