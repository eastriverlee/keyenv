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
    CommandSummary(verb: "export", arguments: "[NAME...]",
                   summary: "export lines for a shell to eval"),
    CommandSummary(verb: "run", arguments: "<NAME>[,<NAME>] <command>",
                   summary: "run a command with those values set"),
    CommandSummary(verb: "run", arguments: "--all <command>",
                   summary: "the same, with every stored value"),
    CommandSummary(verb: "run", arguments: "<command>",
                   summary: "the same, names read from .monkeys"),
    CommandSummary(verb: "shell-init", arguments: "",
                   summary: "add that eval to your startup file"),
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
    \(outputStyle("monkeys", .bold, .brand)) - environment variables kept in your operating system's keyring

    \(commandLines.joined(separator: "\n"))

    Spend a value on one command:

      \(outputStyle("monkeys run OPENROUTER_API_KEY ./bench", .argument))

    A project keeps its names in a \(projectFileName) file, with the profile they live in:

      \(outputStyle("@test", .argument))
      \(outputStyle("DATABASE_URL", .argument))
      \(outputStyle("STRIPE_SECRET_KEY", .argument))

    In that directory or below it, run takes only the command, and set, preview,
    remove and export read and write that profile:

      \(outputStyle("monkeys run ./bench", .argument))
      \(outputStyle("monkeys set STRIPE_SECRET_KEY", .argument))        stored as test/STRIPE_SECRET_KEY

    A leading @profile picks another set of values anywhere:

      \(outputStyle("monkeys run @staging ./deploy", .argument))
      \(outputStyle("monkeys set @staging DATABASE_URL", .argument))

    Or put every value into every shell you open. monkeys shell-init writes this
    into your startup file:

      \(outputStyle(shellInitLine, .argument))

    \(styledAgentGuide)
    """
}
