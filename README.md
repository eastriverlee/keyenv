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

## LLMs read `.env`; not anymore.

For LLMs, `cat .env` is just too
tempting, and once it's in the transcript, it's there for good. The usual
ways to live with that:

1. Ignore it.
2. Trust the provider.
3. Rotate the key after it leaks.

Someone will call it a skill issue. It isn't. There has never been a safe way
for the people on a project to share a secret and use it, so it went in a
file. C had a memory problem too, and being careful didn't fix it. Rust did.

`monkeys` keeps each secret in your vault and hands it to one command at a
time. Nothing prints a stored secret, the command you hand it to included, so there
is nothing to read.

## Quickstart

```sh
curl -fsSL https://monk3ys.dev/install | sh
monkeys set OPENROUTER_API_KEY
```

Write the thing that needs the key. It reads a variable, the way any program
reads one:

```sh
cat > hello.sh <<'SCRIPT'
#!/bin/sh
curl -s https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"google/gemma-4-26b-a4b-it:free","messages":[{"role":"user","content":"say hello world"}]}' |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["choices"][0]["message"]["content"].strip())'
SCRIPT
chmod +x hello.sh
```

Then let monkeys hand it over:

```sh
monkeys run OPENROUTER_API_KEY ./hello.sh
```

> ```
> Hello world!
> ```

The key is in that one process and nowhere else. It never reached your shell
history, your startup file, or the line you just typed. `run` becomes the
command once the secrets are set, so the exit status, the output and the signals
are the command's own.

A project that already has `.env` files moves them in with `monkeys kill`,
which asks, key by key, whether each one is a secret or a public value, and
deletes the files once everything is stored.

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

## Documentation

Everything else, from the command list to what `run` hands back, is
[DOCS.md](DOCS.md), rendered with search at <https://docs.monk3ys.dev>.

## Sponsoring

If it has saved you a key once, you know what it is worth.
[Sponsoring](https://github.com/sponsors/onethreeeseven) keeps the builds
current, the plugin working in each new agent, and the redaction ahead of new
ways output leaks. One-time is fine.

## License

MIT
