struct CommandSummary {
    let verb: String
    let arguments: String
    let summary: String
}

let commandSummaries = [
    CommandSummary(verb: "set", arguments: "<KEY> [--clipboard]",
                   summary: "store a secret typed, piped or pasted"),
    CommandSummary(verb: "set", arguments: "--public <KEY>",
                   summary: "write a plain value into .monkeys"),
    CommandSummary(verb: "set", arguments: "[@profile] [--all]",
                   summary: "prompt for each key the profile lacks"),
    CommandSummary(verb: "forget", arguments: "<KEY>",
                   summary: "delete one stored secret"),
    CommandSummary(verb: "forget", arguments: "@profile[,profile...]",
                   summary: "delete every secret of those profiles"),
    CommandSummary(verb: "forget", arguments: "+namespace",
                   summary: "the same for every profile under it"),
    CommandSummary(verb: "rename", arguments: "@old @new",
                   summary: "a profile's new name, vault and file"),
    CommandSummary(verb: "rename", arguments: "+old +new",
                   summary: "the same for every profile of +old"),
    CommandSummary(verb: "run", arguments: "<KEY[,KEY...]> <command>",
                   summary: "run a command with those secrets set"),
    CommandSummary(verb: "run", arguments: "--all <command>",
                   summary: "the same, with every stored secret"),
    CommandSummary(verb: "run", arguments: "--no-redact <command>",
                   summary: "the same, output untouched"),
    CommandSummary(verb: "run", arguments: "<command>",
                   summary: "the same, keys read from .monkeys"),
    CommandSummary(verb: "pack", arguments: "[path] [--only ...]",
                   summary: "one encrypted file of the profiles"),
    CommandSummary(verb: "unpack", arguments: "<name> [dir] [--keep]",
                   summary: "store its secrets, write its .monkeys"),
    CommandSummary(verb: "eat", arguments: "[--public KEY[,KEY...]]",
                   summary: "move the .env files here into monkeys"),
    CommandSummary(verb: "fill", arguments: "@a --with @b",
                   summary: "give @a the keys it lacks, from @b"),
    CommandSummary(verb: "list", arguments: "",
                   summary: "the whole vault, as blocks by profile"),
    CommandSummary(verb: "preview", arguments: "[KEY[,KEY...]]",
                   summary: "show each secret masked, with length"),
    CommandSummary(verb: "doctor", arguments: "[--short]",
                   summary: "what each profile has and lacks"),
    CommandSummary(verb: "export", arguments: "[KEY[,KEY...]]",
                   summary: "vault lookups for a startup file"),
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
    \(outputStyle("monkeys", .bold, .brand)) - .env you can hand to an LLM, or git add

    \(commandLines.joined(separator: "\n"))

    Spend a secret on one command:

      \(outputStyle("monkeys run OPENROUTER_API_KEY ./hello.sh", .argument))

    A project keeps its keys in \(projectFileName): the first line names the
    project, and each @ line opens a profile the keys below belong to:

      \(outputStyle("+foo", .argument))
      \(outputStyle("@test,production", .argument))
      \(outputStyle("DATABASE_URL", .argument))
      \(outputStyle("STRIPE_SECRET_KEY", .argument))
      \(outputStyle("@production", .argument))
      \(outputStyle("SENTRY_DSN", .argument))

    In that directory or below it within the checkout, run takes only the
    command, and set, preview and forget read and write the first profile:

      \(outputStyle("monkeys run ./hello.sh", .argument))
      \(outputStyle("monkeys set STRIPE_SECRET_KEY", .argument))      stored as foo.test/STRIPE_SECRET_KEY
      \(outputStyle("monkeys set", .argument))                        each key it lacks, one prompt each

    A value that is not secret, PORT=3000 and the like, is a KEY=value line in
    the same file, under the same @ block. run puts it in the environment
    straight from the file, and the vault never sees it:

      \(outputStyle("monkeys set --public PORT", .argument))        Value: 3000, written as PORT=3000

    Each profile gets the keys of every block that lists it, and the first
    profile in the file is the one run uses when none is given:

      \(outputStyle("monkeys run @production ./deploy", .argument))
      \(outputStyle("monkeys doctor", .argument))                     which profile lacks what

    A profile that shares most of its secrets with another is filled from it.
    fill moves only the keys the target lacks, never a secret it already
    holds, and says which keys moved:

      \(outputStyle("monkeys fill @production --with @test", .argument))

    A profile's name changes in the vault and in the file at once, and a
    namespace's for every profile under it. rename refuses a target that
    already holds a key, so two profiles never merge by accident:

      \(outputStyle("monkeys rename @staging @preview", .argument))
      \(outputStyle("monkeys rename +foo +bar", .argument))

    A leading @profile picks another declared profile, and a prefix that fits
    only one of them is enough. From outside the project, or for another
    project's profile, say the namespace too, @namespace.profile:

      \(outputStyle("monkeys set @production SENTRY_DSN", .argument))   stored as foo.production/SENTRY_DSN
      \(outputStyle("monkeys set @foo.production SENTRY_DSN", .argument))    the same, from anywhere

    A key stored outside any project has no profile and needs no @. Inside
    a project every command is scoped to its profile, so a bare @ says no
    profile: it sets the file aside, keys are given again, and the keys with
    no profile are reached without leaving the directory:

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
    the file mentions. The bundle keeps that shape, project and all, and
    unpack writes it back as the project file. It goes to /tmp/a.monsecrets,
    outside any repository; a path before --only puts it elsewhere, into a
    directory you name or at a file you name, and --open reveals it in your
    file manager, ready to drag.
    pack asks for a passphrase; unpack asks again, stores the secrets,
    writes the keys into .monkeys at the root of the git checkout you are
    in, here when there is none, or in the directory you name, and deletes
    the bundle, since it has done its job; --keep leaves it:

      \(outputStyle("monkeys pack", .argument))                   /tmp/a.monsecrets
      \(outputStyle("monkeys pack ~/Desktop", .argument))         a.monsecrets, there
      \(outputStyle("monkeys pack --only @test", .argument))      the same, one profile
      \(outputStyle("monkeys pack --only OPENROUTER_API_KEY", .argument))
      \(outputStyle("monkeys pack --only @test,production DATABASE_URL", .argument))
      \(outputStyle("monkeys pack shared --only @test @production SENTRY_DSN", .argument))
      \(outputStyle("monkeys unpack a", .argument))

    A project that still has .env files moves them in with one command. eat
    asks, key by key, whether each one is a secret for the vault or a public
    value for .monkeys, writes the file, and deletes the .env files once
    everything is stored. Naming the public keys answers every question up
    front, so it asks nothing and needs no terminal:

      \(outputStyle("monkeys eat", .argument))
      \(outputStyle("monkeys eat --public PORT,NODE_ENV", .argument))

    \(styledAgentGuide)
    """
}
