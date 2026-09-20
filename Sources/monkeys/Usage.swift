struct CommandSummary {
    let verb: String
    let arguments: String
    let summary: String
}

let commandSummaries = [
    CommandSummary(verb: "set", arguments: "<NAME>",
                   summary: "store a value typed or piped in"),
    CommandSummary(verb: "list", arguments: "",
                   summary: "print every stored name"),
    CommandSummary(verb: "preview", arguments: "[NAME...]",
                   summary: "show each value masked, with length"),
    CommandSummary(verb: "remove", arguments: "<NAME>",
                   summary: "delete one stored value"),
    CommandSummary(verb: "run", arguments: "<NAME>[,<NAME>] <command>",
                   summary: "run a command with those values set"),
    CommandSummary(verb: "run", arguments: "--all <command>",
                   summary: "the same, with every stored value"),
    CommandSummary(verb: "run", arguments: "--no-redact <command>",
                   summary: "the same, output untouched"),
    CommandSummary(verb: "run", arguments: "<command>",
                   summary: "the same, names read from .monkeys"),
    CommandSummary(verb: "export", arguments: "[NAME...]",
                   summary: "keyring lookups for a startup file"),
    CommandSummary(verb: "pack", arguments: "[name] [--only ...]",
                   summary: "one encrypted file of the profiles"),
    CommandSummary(verb: "unpack", arguments: "<name> [directory]",
                   summary: "store its values, write its .monkeys"),
    CommandSummary(verb: "fill", arguments: "@a --with @b",
                   summary: "give @a the names it lacks, from @b"),
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

    Spend a value on one command:

      \(outputStyle("monkeys run OPENROUTER_API_KEY ./hello.sh", .argument))

    A project keeps its names in \(projectFileName), under the profile they live in:

      \(outputStyle("@foo", .argument))
      \(outputStyle("DATABASE_URL", .argument))
      \(outputStyle("STRIPE_SECRET_KEY", .argument))

    In that directory or below it within the checkout, run takes only the
    command, and set, preview
    and remove read and write that profile:

      \(outputStyle("monkeys run ./hello.sh", .argument))
      \(outputStyle("monkeys set STRIPE_SECRET_KEY", .argument))        stored as foo/STRIPE_SECRET_KEY

    A profile line can name several profiles, and a file can have several
    blocks. Each profile gets the names of every block that lists it; the first
    profile in the file is the one run uses when none is given:

      \(outputStyle("@test.foo,foo", .argument))
      \(outputStyle("DATABASE_URL", .argument))
      \(outputStyle("@foo", .argument))
      \(outputStyle("SENTRY_DSN", .argument))

      \(outputStyle("monkeys run @foo ./deploy", .argument))
      \(outputStyle("monkeys doctor", .argument))                     which profile lacks what

    A profile that shares most of its values with another is filled from it.
    fill moves only the names the target lacks, never a value it already
    holds, and says which names moved:

      \(outputStyle("monkeys fill @foo --with @test.foo", .argument))

    A leading @profile picks another declared profile, and a prefix that fits
    only one of them is enough:

      \(outputStyle("monkeys set @foo SENTRY_DSN", .argument))      stored as foo/SENTRY_DSN

    A name stored outside any project has no prefix and needs no @. Inside a
    project every command is scoped to its profile, so a bare @ says the
    personal profile instead: it sets the file aside, names are given again,
    and the unprefixed names are reached without leaving the directory:

      \(outputStyle("monkeys run TYPESAFE_API_KEY claude", .argument))     outside a project
      \(outputStyle("monkeys run @ TYPESAFE_API_KEY claude", .argument))   inside one, the same value

    For a shell that should carry values from startup, export writes the lines
    to paste into your startup file yourself. Each asks the keyring for one
    value when the shell starts; none of them holds one:

      \(outputStyle("monkeys export TYPESAFE_API_KEY", .argument))
      \(outputStyle("monkeys export", .argument))                the project's names

    Share the project's profiles as one encrypted file: every profile the
    file declares and every name, unless --only says which. After it, a
    @profile (or @a,b, several at once) opens a block and the names after
    it belong to every profile in that block, the way the file is written;
    names with no @ before them come from the default profile, the first
    the file mentions. The bundle keeps that shape, and unpack writes it
    back as the project file. The file is named after the first profile it
    carries unless you name it, before --only.
    pack asks for a passphrase; unpack asks again, stores the values, and
    writes the names into .monkeys at the root of the git checkout you are
    in, here when there is none, or in the directory you name:

      \(outputStyle("monkeys pack", .argument))                   writes test.foo.monkeys
      \(outputStyle("monkeys pack --only @foo", .argument))       writes foo.monkeys
      \(outputStyle("monkeys pack --only OPENROUTER_API_KEY", .argument))
      \(outputStyle("monkeys pack --only @test.foo,foo OPENROUTER_API_KEY", .argument))
      \(outputStyle("monkeys pack shared --only @test.foo @foo SENTRY_DSN", .argument))
      \(outputStyle("monkeys unpack test.foo", .argument))

    \(styledAgentGuide)
    """
}
