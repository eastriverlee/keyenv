# keyenv

Environment variables kept in the macOS keychain, put into your shell at startup.

A secret written into `~/.zshrc` is readable by anything that can read your home
directory, and it follows you into dotfile backups and git history. `keyenv`
stores it as a keychain item and prints an `export` line when a shell asks for
one.

## Install

Needs macOS 13 or later and a Swift toolchain (Xcode, or the Command Line
Tools).

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

Store a value. The prompt hides what you type:

```
$ keyenv set OPENROUTER_API_KEY
Value:
stored OPENROUTER_API_KEY
```

Add one line to `~/.zshrc`, below whatever puts the install directory on
`PATH`:

```sh
eval "$(keyenv export)"
```

Every shell you open from then on has the stored names in its environment.

## Commands

| command | what it does |
| --- | --- |
| `keyenv set <NAME>` | read a value and store it |
| `keyenv get <NAME>` | print one value |
| `keyenv list` | print every stored name |
| `keyenv remove <NAME>` | delete one value |
| `keyenv export [NAME...]` | print shell export lines; all names when none are given |

There is no way to pass a value as a command line argument, which keeps it out
of your shell history and out of the process table. When standard input is not
a terminal, `set` reads the value from there:

```sh
pbpaste | keyenv set GITHUB_TOKEN
```

Storing a name that already exists replaces its value.

## How it stores things

Each variable is a generic password item in your login keychain under the
service name `keyenv`, with the variable name as the account. Search Keychain
Access for `keyenv` and you will see them; delete one there and it is gone.
The same item answers to:

```sh
security find-generic-password -s keyenv -a OPENROUTER_API_KEY
```

Items are created with `kSecAttrAccessibleAfterFirstUnlock`, so a shell that
starts while the screen is locked can still read them.

`export` single-quotes each value and escapes any quote inside it, so a value
carrying quotes, spaces or newlines survives `eval` unchanged.

## Caveats

`eval "$(keyenv export)"` puts every stored value into the environment of every
process started from that shell. To give a secret to one command only, leave it
out of the export and read it at the call site:

```sh
OPENROUTER_API_KEY="$(keyenv get OPENROUTER_API_KEY)" ./run-eval
```

The binary carries an ad-hoc signature, whose identity is a hash of the binary
itself. A rebuild changes that identity, so the keychain may ask you to allow
access once when the new build first reads an item the old one stored.

## License

MIT
