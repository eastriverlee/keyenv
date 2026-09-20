<p align="center">
  <img src="monkeys.svg" alt="" width="200">
</p>

<h1 align="center">monkeys</h1>

<p align="center">
  A cross-platform <code>.env</code> alternative for the LLM era.<br>
  The name reads as <em>mon keys</em>: my keys.
</p>

<p align="center">
  <img alt="license" src="https://img.shields.io/github/license/eastriverlee/monkeys?color=E94100">
  <img alt="swift 6.1" src="https://img.shields.io/badge/swift-6.1-E94100">
  <img alt="macOS and Linux" src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-E94100">
</p>

<p align="center">
  <img src="terminal.svg" alt="monkeys run refusing a missing secret, then running the command, then preview" width="640">
</p>

## Overview

`monkeys` keeps each secret in your operating system's vault and hands it to
one command at a time. The keys a project needs are listed in a committed
`.monkeys` file, the secrets never leave the vault, and nothing prints a
stored secret, the command you hand it to included.

It exists for two reasons, and either would have been enough.

1. **LLMs read `.env`.** `cat .env` is just too tempting, and once it's in
   the transcript, it's there for good. The usual answers are to ignore it,
   trust the provider, or rotate the key after it leaks. Someone will call it
   a skill issue. It isn't: there has never been a safe way for the people on
   a project to share a secret and use it, so it went in a file. C had a
   memory problem too, and being careful didn't fix it. Rust did.

2. **`.env` was never good, even for people.** Sharing it means pasting the
   whole file into a chat. Test and production mean `.env.test`,
   `.env.production` and a loader that picks one. Keeping it out of git means
   an `.env.example` that drifts and a `.gitignore` line that guards it.
   `monkeys` folds that into one committed file: profiles, `pack` for the
   whole thing or the part a teammate needs, and nothing in the repository to
   keep secret.

## Install

On macOS or Linux, from the latest release:

```sh
curl -fsSL https://monk3ys.dev/install | sh
```

The script picks the build for your operating system and processor, checks the
published checksum, and installs into `~/.local/bin`. Set `INSTALL_DIRECTORY`
to put it elsewhere. It is short, and reading it first is a fine habit.

With Homebrew, which then upgrades it along with everything else:

```sh
brew install eastriverlee/tap/monkeys
```

From source, with Swift 6.1 or later, on macOS 13 or later or on Linux:

```sh
git clone https://github.com/eastriverlee/monkeys
cd monkeys
make install
```

On Linux, `monkeys` reaches the vault through `secret-tool`: install
`libsecret-tools` on Debian and Ubuntu, `libsecret` on Fedora and Arch.

### For a coding agent

The binary is the whole tool, and an agent that can run a shell can already
use it. The skill at `plugins/monkeys/skills/monkeys/SKILL.md` is what makes
it reach for `monkeys` on its own instead of asking you to paste a key.
`plugins/monkeys` is an [Agent Plugins](https://agent-plugins.org) package,
and the repository is a marketplace for it in the two clients that have one.

**Claude Code**

```sh
claude plugin marketplace add eastriverlee/monkeys
claude plugin install monkeys@eastriverlee
```

`/monkeys:install` then fetches the binary, and a session that starts without
one says so.

**Codex**

```sh
codex plugin marketplace add eastriverlee/monkeys
codex plugin add monkeys@eastriverlee
```

The binary is installed separately, from the section above.

**Anything else**

Copy `plugins/monkeys/skills/monkeys/SKILL.md` into whatever directory your agent reads
skills from; <https://monk3ys.dev/skill> serves that one file.

The skill restates a few invocations so an agent knows them before it runs
anything. `make check` holds that copy to the binary, failing when the skill
names a command `monkeys help` does not list.

## Quickstart

### Store

```sh
monkeys set SUPER_SECRET
```

Type `sesame` at the prompt.

### Spend

```sh
monkeys run SUPER_SECRET sh -c '
  test "$SUPER_SECRET" = sesame && echo opened || echo closed
  echo "the word was $SUPER_SECRET"
'
```

> ```
> opened
> the word was [redacted SUPER_SECRET]
> ```

The right word reached the command, and what the command printed came back
with the secret taken out. `run` becomes the command once the secret is set,
so the exit status, the output and the signals are the command's own.

### Without monkeys

```sh
sh -c 'test "$SUPER_SECRET" = sesame && echo opened || echo closed'
```

> ```
> closed
> ```

### Remove and retry

```sh
monkeys remove SUPER_SECRET
monkeys run SUPER_SECRET sh -c '
  test "$SUPER_SECRET" = sesame && echo opened || echo closed
'
```

> ```
> removed SUPER_SECRET
> monkeys: SUPER_SECRET is not stored yet
> nothing ran. a human has to store it, then try again:
>   monkeys set SUPER_SECRET
> ```

Nothing ran at all: a missing secret stops `run` before the command starts,
and the message says what to do, which is what an agent passes on.

## Documentation

Everything else, from the command list to what `run` hands back, is
[DOCS.md](DOCS.md), rendered with search at <https://docs.monk3ys.dev>.

## Contributing

Bugs and proposals go through the issue templates, which ask for what a fix
or a decision needs. A pull request runs `make check` first: it holds the help
text, the skill and the docs to the binary.

## Sponsoring

If it has saved you a key once, you know what it is worth.
[Sponsoring](https://github.com/sponsors/onethreeeseven) keeps the builds
current, the plugin working in each new agent, and the redaction ahead of new
ways output leaks. One-time is fine.

## License

MIT
