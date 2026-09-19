<p align="center">
  <img src="monkeys.svg" alt="" width="200">
</p>

<h1 align="center">monkeys</h1>

<p align="center">
  Environment variables kept in your operating system's keyring,<br>
  handed to one command at a time.<br>
  The name reads as <em>mon keys</em>: my keys.
</p>

<p align="center">
  <img alt="license" src="https://img.shields.io/github/license/eastriverlee/monkeys?color=E94100">
  <img alt="swift 6.0" src="https://img.shields.io/badge/swift-6.0-E94100">
  <img alt="macOS and Linux" src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-E94100">
</p>

<p align="center">
  <img src="terminal.svg" alt="monkeys run refusing a missing value, then running the command, then preview" width="640">
</p>

**LLMs read `.env`, not anymore.** No one has to, but `cat .env` is just too
tempting, and once it's in the transcript, it's there for good. The usual
ways to live with that:

1. Ignore it.
2. Trust the provider.
3. Rotate the key after it leaks.

Someone will call it a skill issue. It isn't. There has never been a safe way
for the people on a project to share a secret and use it, so it went in a
file. C had a memory problem too, and being careful didn't fix it. Rust did.

`monkeys` keeps each secret in your keyring and hands it to one command at a
time. Nothing prints a stored value, so there is nothing to read.

## Quickstart

```sh
curl -fsSL https://monk3ys.dev/install | sh
monkeys set OPENROUTER_API_KEY
```

Write the thing that needs the key. It reads a variable, the way any program
reads one:

```sh
cat > hello <<'SCRIPT'
#!/bin/sh
curl -s https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"google/gemma-4-26b-a4b-it:free","messages":[{"role":"user","content":"say hello world"}]}' |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["choices"][0]["message"]["content"].strip())'
SCRIPT
chmod +x hello
```

Then let monkeys hand it over:

```sh
$ monkeys run OPENROUTER_API_KEY ./hello
Hello world!
```

The key is in that one process and nowhere else. It never reached your shell
history, your startup file, or the line you just typed. `run` becomes the
command once the values are set, so the exit status, the output and the signals
are the command's own.

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

Tap it once and the bare name works from then on:

```sh
brew tap eastriverlee/tap
brew install monkeys
```

From source, with a Swift toolchain and macOS 13 or later:

```sh
git clone https://github.com/eastriverlee/monkeys
cd monkeys
make install
```

On Linux, `monkeys` reaches the keyring through `secret-tool`: install
`libsecret-tools` on Debian and Ubuntu, `libsecret` on Fedora and Arch.

### For a coding agent

The binary is the whole tool, and an agent that can run a shell can already use
it. Installing the skill is what makes it reach for `monkeys` on its own,
rather than asking you to paste a key.

In Claude Code:

```sh
claude plugin marketplace add eastriverlee/monkeys
claude plugin install monkeys@monkeys
```

`/monkeys:install` then fetches the binary, and a session that starts without
one says so. Elsewhere, copy `skills/monkeys/SKILL.md` into whatever directory
your agent reads skills from.

The skill restates a few invocations so an agent knows them before it runs
anything. `make check` holds that copy to the binary, failing when the skill
names a command `monkeys help` does not list.

## Commands

| command | what it does |
| --- | --- |
| `monkeys set <NAME>` | read a value and store it |
| `monkeys list` | print every stored name |
| `monkeys preview [NAME...]` | print each value masked, with its length |
| `monkeys remove <NAME>` | delete one value |
| `monkeys run <NAME>[,<NAME>] <command>` | run a command with those values in its environment |
| `monkeys run --all <command>` | the same, with every stored value |
| `monkeys run <command>` | the same, with the names a `.monkeys` file lists |
| `monkeys export [NAME...]` | keyring lookup lines, to paste into a startup file |
| `monkeys pack [name]` | write the profile as `name.monkeys`, encrypted |
| `monkeys unpack <name>` | store its values, write its `.monkeys` |

`monkeys` takes no value as an argument, so storing one never types it: your
shell history and the process table both see `monkeys set GITHUB_TOKEN` and
nothing more. When standard input is not a terminal, `set` reads the value from
there:

```sh
pbpaste | monkeys set GITHUB_TOKEN        # macOS
wl-paste | monkeys set GITHUB_TOKEN       # Linux, Wayland
```

Naming no name means every name, for `preview` and `export`. `run` asks to be
told, since the names are how it knows what to check for and what to leave out;
`--all` is there for when you would rather not say. Any command takes a leading
`@profile`, which is covered below.

Output is coloured only when it is going to a terminal, and never for `list`,
whose output a script reads. `NO_COLOR` turns colour off,
`CLICOLOR_FORCE` turns it on for a pipe, and an empty value for either counts
as unset.

## Spending a value

Storing one looks like this:

```
$ monkeys set OPENROUTER_API_KEY
Value:
stored OPENROUTER_API_KEY
give it to a command with:
  monkeys run OPENROUTER_API_KEY <command>
```

A command that needs two gets both, and nothing else:

```sh
monkeys run OPENROUTER_API_KEY,GITHUB_TOKEN ./deploy
```

### Where the variable is expanded

`run` sets the variable for the command it starts, so that command is what
expands it. Written into the `monkeys run` line itself, your own shell gets
there first, and yours does not have the value:

```sh
monkeys run OPENROUTER_API_KEY curl -H "Authorization: Bearer $OPENROUTER_API_KEY" ...
# sends: Authorization: Bearer
```

Single quotes pass the text through untouched, so a shell that `run` starts is
the one that expands it:

```sh
monkeys run OPENROUTER_API_KEY sh -c 'curl -H "Authorization: Bearer $OPENROUTER_API_KEY" ...'
```

A script file works for the same reason, and reads better.

A name you have not stored stops the run before it starts:

```
$ monkeys run OPENROUTER_API_KEY,ANTHROPIC_API_KEY ./bench
monkeys: ANTHROPIC_API_KEY is not stored yet
nothing ran. ask the person to store it, then try again:
  monkeys set ANTHROPIC_API_KEY
```

That message is written to be passed on. An agent that meets it knows which
values are missing, that nothing happened, and what to ask its person for.

## Projects and profiles

A project names what it needs once, in a `.monkeys` file next to the code:

```
@shop
DATABASE_URL
STRIPE_SECRET_KEY
OPENROUTER_API_KEY
```

The first line is the profile, and every project has one; the rest are names,
and `#` starts a comment. Commit it. It is the secret half of `.env.example`,
and a project keeps one or the other, since two lists of the same names drift.

In that directory or any below it, `run` takes only the command:

```sh
monkeys run ./hello
monkeys run npm run dev
```

The profile scopes every name. `monkeys set STRIPE_SECRET_KEY` there stores
`shop/STRIPE_SECRET_KEY`, which is what `run` reads, and `preview` with no
names gives the file's names from that profile. `list` stays global and
shows the prefixes, so you can see which project each value belongs to.

The profile's name is the project's and its values are yours. Everyone who
clones the repository gets the same names, and each of them fills their own
keyring, so a `.monkeys` file can be committed and a keyring never has to be.

A profile never reads from the personal one. Names stored without a profile
are yours alone, and a name missing in `@shop` is missing there even when a
bare copy exists, so a project cannot quietly pick up a value meant for
another.

A leading `@profile` picks another set of values for the same names, anywhere.
A bare `@` is the personal profile, and since no project lives there, it also
sets the file aside and takes names again, which is how one value reaches a
tool you start from any directory:

```sh
monkeys run @staging ./deploy
monkeys set @staging DATABASE_URL
monkeys run @ TYPESAFE_API_KEY claude
```

A missing value says where it is missing from, and the `set` it asks for works
from any directory:

```
$ monkeys run ./hello
monkeys: STRIPE_SECRET_KEY is not stored yet in @shop
nothing ran. ask the person to store it, then try again:
  monkeys set @shop STRIPE_SECRET_KEY
```

Inside a project, everything after `run` is the command. The older form,
`monkeys run NAME ./hello`, tries to run a program called `NAME` there, and the
error says which file is supplying the names instead.

### Sharing a profile

A profile leaves the keyring as one encrypted file, and only that way:

```sh
$ monkeys pack
Passphrase:
Again:
wrote shop.monkeys: @shop, 3 values
```

The file takes the profile's name. A word after `pack` names it otherwise,
and `monkeys pack @staging` bundles another profile.

It carries the profile's name, the names the project lists, and their values,
sealed with ChaCha20-Poly1305 under a key scrypt derives from the passphrase.
The file is safe to send over whatever you already use; the passphrase goes
another way. A pack with a value still missing refuses, since a bundle
that fills half a profile is a bug for whoever receives it.

The other side runs `unpack` where the project should live:

```sh
$ monkeys unpack shop
Passphrase:
wrote .monkeys: @shop, 3 names
stored shop/DATABASE_URL, shop/STRIPE_SECRET_KEY, shop/OPENROUTER_API_KEY
```

The values go into that person's keyring under the bundle's profile, `shop/`,
and the profile and names become a `.monkeys` file in the current directory,
so `monkeys run ./hello` works from the next command. When a `.monkeys` file
is already there, `unpack` keeps it. It stores nothing if that file names
another profile or other names, and says which; the file is committed, and a
bundle does not get to rewrite it.

Both commands read the passphrase from standard input when it is not a
terminal, for the rare script that needs to.

A bundle has no place in a repository, and the ignore rule needs two lines,
because `*.monkeys` alone also matches the `.monkeys` file you do commit:

```
*.monkeys
!.monkeys
```

## Every shell, if you want it

`run` hands a value to one process, and `monkeys run @shop zsh` hands a whole
profile to one shell, which forgets it on exit. For a value that every shell
should carry from startup, `export` writes the lines and you paste them:

```sh
$ monkeys export @ TYPESAFE_API_KEY
export TYPESAFE_API_KEY="$(security find-generic-password -s monkeys -a TYPESAFE_API_KEY -w)"
```

No value is in that line. It asks the keychain when the shell starts, the way
you would have written it by hand, and on Linux it asks `secret-tool` instead.
`monkeys` writes nothing into your startup file for you: a value that every
process on the machine inherits is a decision to make with the file open.

The keychain treats `security` as its own program, so the first shell that
runs the line asks once whether to allow it. Answer Always Allow and it stays
quiet.

## Looking without reading

Nothing here prints a stored value. The closest is `preview`, which answers the
question you usually have, which is whether the right value is in there:

```
$ monkeys preview
GITHUB_TOKEN        gh...f 40
OPENROUTER_API_KEY  sk...2 73
```

It shows the first two characters, the last one, and the length. A value is
masked whole whenever fewer than five characters would stay hidden, so nothing
under eight characters long gives any of itself away:

```
$ monkeys preview SHORT_ONE
SHORT_ONE  ... 6
```

A length and a two-character prefix are enough to tell a key pasted whole from
one that lost a character on the way, or one provider's key from another's. To
read a value in full, open Keychain Access or your keyring's own browser, where
the decision to look at a secret is yours and deliberate.

`monkeys help` ends with the same ground written for an agent to read: spend a
value through `run`, pass on the message when one is missing, and leave storing
to the person.

## What gets replaced

`set` on a name you already stored replaces its value and says nothing about
it. The previous value is gone, and the keyring keeps no history to recover it
from.

`run` sets the names you give it in the command's environment, so a variable
the shell already exported is overridden for that command. Names you leave out
are passed through untouched.

`run`, `export` and `pack` each check every name before doing anything, so a
name you never stored stops them with nothing done. A command cannot start with
half of its secrets, a startup file cannot ask for a value that is not there,
and a bundle cannot carry half of a profile.

## How it stores things

Each variable is one keyring item carrying two attributes, `service` set to
`monkeys` and `account` set to the variable name, labelled `monkeys: <NAME>`.
Your desktop's own keyring tools see the same items, and deleting one there
deletes it for `monkeys`.

On macOS that is a generic password in the login keychain. Search Keychain
Access for `monkeys`, or ask for one by name:

```sh
security find-generic-password -s monkeys -a OPENROUTER_API_KEY
```

Items are created with `kSecAttrAccessibleAfterFirstUnlock`, so a shell that
starts while the screen is locked can still read them.

On Linux the same attributes go to the Secret Service D-Bus API through
`secret-tool`, which is gnome-keyring on most desktops and KWallet on KDE:

```sh
secret-tool lookup service monkeys account OPENROUTER_API_KEY
```

## Caveats

`run` scopes a secret to one process, and it cannot follow the value any
further. A command free to print what it reads will print this too, and no
filter here would be honest about catching that. What `run` settles is that
the value never appears in the line you typed.

On macOS a binary built from source carries an ad-hoc signature, whose identity
is a hash of the binary itself. A rebuild changes that identity, so the keychain
may ask you to allow access once when the new build first reads an item the old
one stored.

On Linux the Secret Service is a desktop session service. Over SSH or in a
container there is usually no session bus and no keyring daemon, and `monkeys`
fails saying so. Machines like that want a different mechanism, not this one.

## License

MIT
