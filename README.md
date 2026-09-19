# keyenv

Environment variables kept in your operating system's keyring, put into your
shell at startup.

A secret written into `~/.zshrc` is readable by anything that can read your home
directory, and it follows you into dotfile backups and git history. `keyenv`
stores it in the keyring and prints an `export` line when a shell asks for one.

On macOS the keyring is the login keychain, reached through Security.framework.
On Linux it is whatever answers the Secret Service D-Bus API, which is
gnome-keyring on most desktops and KWallet on KDE, reached through
`secret-tool`.

## Install

Needs a Swift toolchain, and macOS 13 or later, or a Linux distribution Swift
supports. On Linux, install `secret-tool` as well: `libsecret-tools` on Debian
and Ubuntu, `libsecret` on Fedora and Arch.

```sh
git clone https://github.com/eastriverlee/keyenv
cd keyenv
make install
```

The binary lands in `~/.local/bin`. Point `INSTALL_DIRECTORY` somewhere else if
you keep your tools elsewhere:

```sh
make install INSTALL_DIRECTORY=/usr/local/bin
```

## Use

Store a value. The prompt hides what you type, and the first time around it
offers to wire up your shell:

```
$ keyenv set OPENROUTER_API_KEY
Value:
stored OPENROUTER_API_KEY
this shell still has the value it started with; load the stored one with:
  eval "$(keyenv export OPENROUTER_API_KEY)"

no startup file here seems to call keyenv export.
append it to ~/.zshrc now? [y/N] y
appended to ~/.zshrc:
  eval "$(keyenv export)"
open a new shell, or: source ~/.zshrc
```

Two separate things are going on there.

Storing a value cannot reach the shell that ran `keyenv`, because a process only
ever changes its own environment. The `eval` on the third line is how you get
the value into the shell you are standing in.

The offer is about every shell after this one. It comes up when nothing in your
startup file mentions `keyenv export`, and what it appends is:

```sh
# secrets from the keyring, via https://github.com/eastriverlee/keyenv
eval "$(keyenv export)"
```

That goes in once and never changes again. Every `keyenv set` after it reaches
the next shell you open, since `keyenv export` reads whatever is stored at the
time it runs:

```
$ keyenv export
export GITHUB_TOKEN='ghp_0000000000000000'
export OPENROUTER_API_KEY='sk-or-v1-0000000000000000'
```

So the last step is deleting the plain secrets your startup file still carries:

```sh
export OPENROUTER_API_KEY=sk-or-v1-0000000000000000
export GITHUB_TOKEN=ghp_0000000000000000
```

`keyenv shell-init` makes the same append on its own, and says so when the line
is already there. It writes `~/.zshrc` for zsh and `~/.bashrc` for bash
(`~/.bash_profile` on macOS). Set `KEYENV_SHELL_PROFILE` to send it somewhere
else, such as a file your startup file sources.

The append lands at the end of the file, which in almost every startup file is
below the line that puts the install directory on `PATH`. The shell has to find
`keyenv` to run it, so check that order first if a new shell comes up without
your values.

Nothing is written without an answer. When `set` reads its value from a pipe
there is no terminal to ask, so it prints `you can do it later with: keyenv
shell-init` and leaves the file alone.

## Commands

| command | what it does |
| --- | --- |
| `keyenv set <NAME>` | read a value and store it |
| `keyenv get <NAME>` | print one value |
| `keyenv list` | print every stored name |
| `keyenv preview [NAME...]` | print each value masked, with its length |
| `keyenv remove <NAME>` | delete one value |
| `keyenv export [NAME...]` | print shell export lines; all names when none are given |
| `keyenv shell-init` | add the export line to your shell startup file |
| `keyenv help agent` | how an LLM or a script should use this |

There is no way to pass a value as a command line argument, which keeps it out
of your shell history and out of the process table. When standard input is not
a terminal, `set` reads the value from there:

```sh
pbpaste | keyenv set GITHUB_TOKEN        # macOS
wl-paste | keyenv set GITHUB_TOKEN       # Linux, Wayland
```

## Looking without reading

`get` prints a secret in full, which makes it the wrong command for anything
that keeps a record of what it reads, a coding agent and a CI log among them.
`preview` answers the question such a caller actually has, which is whether the
right value is in there:

```
$ keyenv preview
GITHUB_TOKEN        gh...f 40
OPENROUTER_API_KEY  sk...2 73
```

It shows the first two characters, the last one, and the length. A value is
masked whole whenever fewer than five characters would stay hidden, so nothing
under eight characters long gives any of itself away:

```
$ keyenv preview SHORT_ONE
SHORT_ONE  ... 6
```

A length and a two-character prefix are enough to tell a key pasted whole from
one that lost a character on the way, or one provider's key from another's.

`keyenv help agent` prints the same rules for the agent itself to read, along
with how to hand a secret to a command without the value passing through the
agent.

## What gets replaced

`set` on a name you already stored replaces its value and says nothing about
it. The previous value is gone, and the keyring keeps no history to recover it
from.

`eval "$(keyenv export)"` assigns every stored name, so a value already in the
environment gives way to the stored one. Position in `~/.zshrc` settles which
wins: an `export` line below the `eval` survives, one above it is overwritten.

`export` reads every value before it prints the first line, so a run that fails
on a name you never stored prints nothing at all. A shell cannot end up with
half of them set.

## How it stores things

Each variable is one keyring item carrying two attributes, `service` set to
`keyenv` and `account` set to the variable name, labelled `keyenv: <NAME>`.
Your desktop's own keyring tools see the same items, and deleting one there
deletes it for `keyenv`.

On macOS that is a generic password in the login keychain. Search Keychain
Access for `keyenv`, or ask for one by name:

```sh
security find-generic-password -s keyenv -a OPENROUTER_API_KEY
```

Items are created with `kSecAttrAccessibleAfterFirstUnlock`, so a shell that
starts while the screen is locked can still read them.

On Linux the same attributes go to the Secret Service through `secret-tool`,
which puts them in your desktop keyring:

```sh
secret-tool lookup service keyenv account OPENROUTER_API_KEY
```

`export` single-quotes each value and escapes any quote inside it, so a value
carrying quotes, spaces or newlines survives `eval` unchanged.

## Caveats

`eval "$(keyenv export)"` puts every stored value into the environment of every
process started from that shell. To give a secret to one command only, leave it
out of the export and read it at the call site:

```sh
OPENROUTER_API_KEY="$(keyenv get OPENROUTER_API_KEY)" ./run-eval
```

On macOS the binary carries an ad-hoc signature, whose identity is a hash of the
binary itself. A rebuild changes that identity, so the keychain may ask you to
allow access once when the new build first reads an item the old one stored.

On Linux the Secret Service is a desktop session service. Over SSH or in a
container there is usually no session bus and no keyring daemon, and `keyenv`
fails saying so. Machines like that want a different mechanism, not this one.

## License

MIT
