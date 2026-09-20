# Overview

`monkeys` keeps secrets in your operating system's vault and hands them to
one command at a time. It replaces `.env`: the keys a project needs are
committed in `.monkeys`, the secrets stay in each person's keychain or Secret
Service, and `monkeys run` gives them to the command that needs them. No
command prints a stored secret.

## Why it exists

Coding agents read `.env`. A variable was empty, the task was stuck, and
`cat .env` was the shortest way back; the secret is then in the transcript
for good. `monkeys` takes that path away and gives the agent a shorter one:
the secret goes from the vault into the process, a missing one comes back
as a message saying what to ask for, and the output comes back redacted.

People get the same shape. A secret shared with a teammate becomes `pack`
and `unpack`, and `.env`, `.env.example` and the `.gitignore` line between
them collapse into one committed file that lists keys and holds nothing.

## What it is

The same project, the way it is kept today and the way `monkeys` keeps it.
With `.env`, the secrets sit in a file next to the code, and the file is what
you protect, copy and share:

```sh
$ cat .env                          # secrets, on disk, never committed
OPENROUTER_API_KEY=sk-or...
STRIPE_SECRET_KEY=sk_li...

$ cat .env.example                  # the same keys again, kept in step by hand
OPENROUTER_API_KEY=
STRIPE_SECRET_KEY=

$ cat .gitignore                    # so the first file stays out of git
.env

$ ./hello.sh                        # a library loads .env, or you source it
$ cat .env | pbcopy                 # to share it: paste into a chat
```

With `monkeys`, the file holds keys and the vault holds secrets, and each
command gets only what it names:

```sh
$ cat .monkeys                      # keys under a profile, committed
+foo
@test
OPENROUTER_API_KEY
STRIPE_SECRET_KEY

$ monkeys set OPENROUTER_API_KEY    # the secret goes into the vault, once
Secret:

$ monkeys run ./hello.sh            # the command gets them, and nothing else does
$ monkeys pack                      # to share: one encrypted file
$ monkeys unpack a.monsecrets       # on their machine, into their vault
```

The `.monkeys` file replaces all three of `.env`, `.env.example` and the
`.gitignore` line, and it is the one that is committed; `.monvalues` next to
it holds the lines that were never secret, `PORT=3000` and the like, and is
committed too. One binary for macOS
and Linux does the rest: no runtime, no service, and no vault of its own,
since the login keychain and the Secret Service are already there.

## What it is not

Not a secret manager with a server or an audit log. Not a wall against an
agent that sets out to read a secret; it removes the reflex, which is the
everyday problem. Not a vault for `PORT=3000`, which stays in the repository,
in `.monvalues`.

## Where to go next

[Quickstart](/docs/quickstart) spends a first secret in three commands,
[Concepts](/docs/concepts/profile) defines the six words the reference uses,
and [Commands](/docs/commands) has one page per command.

# Concepts

## Key

A key is the name of an environment variable, the `KEY` of `KEY=secret`. It
is what a program reads, what a `.monkeys` file lists, and what every command
takes on its line:

```sh
monkeys set OPENROUTER_API_KEY
monkeys run OPENROUTER_API_KEY ./hello.sh
```

### Form

A key takes letters, digits and `_`, and cannot start with a digit, the rule
POSIX gives for a variable name. `OPENROUTER_API_KEY` is a key;
`openrouter-key` is refused.

### Where a key appears

Keys are public. They are committed in `.monkeys`, they appear in `list` and
in every message, and the process `run` starts sees them as the names of its
variables. `monkeys` takes no secret as an argument, only keys, so storing one
never types it: your shell history and the process table both see `monkeys
set GITHUB_TOKEN` and nothing more.

### One key, several secrets

The same key in two profiles is two secrets, `foo.test/DATABASE_URL` and
`foo.production/DATABASE_URL`, and the key alone, with no profile, is a third.
Which one a command gets is decided by the profile, never by the key.

## Secret

A secret is what a key holds: the API key, token or password itself. It is the
only thing `monkeys` exists to keep, and the only thing it never prints.

### Where it goes

A secret enters the vault through `set`, typed at a prompt, piped in or read
from the clipboard, and leaves it in exactly one way: into the environment of
a command that `run` starts. What that command prints comes back through
`monkeys`, which replaces the secret with `[redacted KEY]` on the way.

### Replacing one

Storing a secret under a key you already stored replaces the old one, and
nothing says so. The previous secret is gone; the vault keeps no history to
recover it from.

### Reading one

No `monkeys` command prints a secret. To read one in full, open the vault
itself, Keychain Access on macOS or the desktop's secret browser on Linux,
where the decision to look at one is yours and deliberate.

## Vault

The vault is the operating system's own secret store, and `monkeys` keeps
nothing anywhere else. There is no file of `monkeys`'s own to back up, leak
or forget, and the desktop's own tools see everything `monkeys` stores.

| platform | vault | reached through |
| --- | --- | --- |
| macOS | the login keychain | Security.framework |
| Linux | whatever answers the [Secret Service](https://specifications.freedesktop.org/secret-service-spec/latest/) API over D-Bus: GNOME Keyring on most desktops, KWallet on KDE | `secret-tool` from libsecret |

### What an item looks like

Each secret is one item carrying two attributes: `service` is `monkeys`, and
`account` is `<profile>/<KEY>`, or `<KEY>` alone for a key with no profile, so a
project's item reads `foo.test/OPENROUTER_API_KEY`. The label is `monkeys: `
followed by the account. Deleting an item in the desktop's tools deletes it
for `monkeys`.

On macOS that is a generic password in the login keychain. Search Keychain
Access for `monkeys`, or ask for one by account:

```sh
security find-generic-password -s monkeys -a OPENROUTER_API_KEY
security find-generic-password -s monkeys -a foo.test/OPENROUTER_API_KEY
```

Items are created with
[`kSecAttrAccessibleAfterFirstUnlock`](https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlock),
so a shell that starts while the screen is locked can still read them.

On Linux the same attributes go through `secret-tool`:

```sh
secret-tool lookup service monkeys account foo.test/OPENROUTER_API_KEY
```

### The keychain prompt on macOS

A binary built from source carries an ad-hoc
code signature,
whose identity is a hash of the binary itself. A rebuild changes that
identity, so the keychain may ask you to allow access once when the new build
first reads an item the old one stored. The release builds are what `brew`
and the install script give you.

### The Secret Service on Linux

The Secret Service is a desktop session service. Over SSH or in a container
there is usually no session bus and no secret daemon, and `monkeys` fails
saying so. Machines like that want a different mechanism, not this one.

## Profile

A profile is a named set of secrets. Every secret `monkeys` stores sits under
one, as `<profile>/<KEY>`, and a project's `.monkeys` file lists its keys
under the profiles they belong to:

```monkeys
+foo
@test
DATABASE_URL
STRIPE_SECRET_KEY
OPENROUTER_API_KEY
```

The `@` line names the profile and the `+` line the namespace it sits in, so
these three are stored as `foo.test/DATABASE_URL` and so on. The keys are the
project's and the secrets are yours: everyone who clones the repository gets
the same profile and the same keys, and each of them fills their own vault,
so a `.monkeys` file can be committed and a vault never has to be.

### The default profile

The first profile a `.monkeys` file mentions is the default, the one every
command uses in that project when none is given. Inside the checkout, `run`
takes only the command, `set` stores under the profile, and `preview` with no
keys shows the file's keys:

```sh
monkeys run ./hello.sh
monkeys set STRIPE_SECRET_KEY        # stores foo.test/STRIPE_SECRET_KEY
monkeys preview
```

`list` shows the whole vault as blocks by profile, so you can see what each
one holds.

### Several profiles

A profile line can name several profiles, and a file can hold several blocks:

```monkeys
+foo
@test,production
DATABASE_URL
STRIPE_SECRET_KEY
@production
SENTRY_DSN
```

A profile's keys are those of every block that lists it: both profiles here
need `DATABASE_URL` and `STRIPE_SECRET_KEY`, and `production` also needs
`SENTRY_DSN`. The default is still the first, `test`, so production is
something you say.

A secret missing in one profile stops only that profile, and only when it is
used: `production` can be half filled while `test` runs. `doctor` shows the
whole picture.

### Choosing a profile

Any command takes a leading `@profile`, which picks another declared one. A
prefix that fits only one of them is enough, the way a short git hash is:

```sh
monkeys run @production ./deploy
monkeys set @production SENTRY_DSN
monkeys run @prod ./deploy           # production, by its prefix
```

A profile the file does not declare is refused with the declared ones listed,
and a prefix that fits several is refused with those, so a typo never becomes
a new profile. A profile name is words of letters, digits, `_` and `-`,
joined by `.`; `test`, `staging` and `production` are the usual three, and the
namespace supplies the part before the dot.

### No profile

A key stored outside any project has no profile and needs no `@`. That is
where a secret that belongs to you rather than to a project lives, such as
the one a tool you start from anywhere reads:

```sh
monkeys set TYPESAFE_API_KEY
monkeys run TYPESAFE_API_KEY claude
```

A project profile never reads from the keys with no profile. A key missing
in `@production` is missing there even when a copy with no profile exists,
so a project cannot quietly pick up a secret meant for another.

Inside a project every command is scoped to that project's profile, so the
keys with no profile are out of reach there: `monkeys run` reads `foo.test/`,
and `monkeys set TYPESAFE_API_KEY` would write `foo.test/TYPESAFE_API_KEY`.
A bare `@` means no profile. It sets the project file aside, so keys are
given again, and reaches those keys without leaving the directory:

```sh
monkeys run @ TYPESAFE_API_KEY claude
monkeys set @ TYPESAFE_API_KEY
monkeys preview @ TYPESAFE_API_KEY
```

It is the same secret either way; the `@` only says which profile to look in
when a file would otherwise decide.

## Namespace

A namespace is the part of a profile's name that belongs to the project. The
`+` line of a `.monkeys` file sets it, and every `@` line in that file is
read with it in front: in a file that starts with `+foo`, `@test` is the
profile `foo.test`, and its secrets are stored as `foo.test/DATABASE_URL`.

### What it is for

Two projects that both call a profile `test` would otherwise share
`test/DATABASE_URL`. With a namespace each keeps its own, since
`bar.test/DATABASE_URL` is another secret, and `list` shows the two under
separate profiles.

### Where it is written

Once, in the file. It is the same in every clone and needs no git remote or
directory name to agree with. A namespace takes letters, digits, `_`, `-` and
`.`, usually the repository's name; a group that publishes several projects
can use reverse domain name notation, as in `+dev.eastriver.foo`.

### Referring to a profile

Inside the project the namespace is never typed. A profile is `@test` or
`@production`, and the file supplies the rest. The full name works from
anywhere, since it is only the profile's name; inside a project, a dotted
name the file does not declare is read as another project's:

```sh
monkeys run @production ./deploy          # inside foo
monkeys preview @foo.production           # from anywhere
monkeys fill @bar.test --with @foo.test   # across projects
```

### Without one

A file with no `+` line names its profiles as written, so `@test` there is
the profile `test`, stored as `test/DATABASE_URL`, and a second project that
also says `@test` would share it.

## .monkeys

A project lists the keys it needs once, in a `.monkeys` file next to the
code. It is the secret half of `.env.example`: the list of what the program
reads, with nothing it reads in it. Commit it.

### Format

```monkeys
+foo
@test,production
DATABASE_URL
STRIPE_SECRET_KEY
@production
SENTRY_DSN
```

| line | meaning |
| --- | --- |
| `+foo` | the namespace, first and at most once |
| `@test,production` | opens a block for one profile or several |
| `DATABASE_URL` | a key, belonging to every profile of the block above it |
| `# ...` | a comment |

The first profile mentioned is the default. A key listed twice for one
profile, a key before any `@` line, or a name that is not a key is refused
with the line quoted.

### Where it is looked for

From the current directory upward, nearest first, stopping at the root of the
git checkout, so a file above the checkout is never read. Outside a checkout
only the current directory counts. Where no file is found the commands take
keys on the line, as they do anywhere else.

### What it replaces

The [twelve-factor](https://12factor.net/config) habit of a `.env` that is
never committed, a `.env.example` that lists the same keys again by hand, and
a `.gitignore` line that keeps the two apart. `.monkeys` is one file, it is
committed, and the secrets are somewhere a repository cannot reach.

### Who writes it

You, or `unpack`, which writes it at the root of the checkout from a bundle.
`doctor` reads it whole and says what each profile still lacks.

## .monvalues

A project's plain values, the `PORT=3000` and `API_URL=...` lines of a `.env`
that were never secret, live in a `.monvalues` file next to `.monkeys`.
Commit it. A project without such values never has the file.

### Format

```monkeys
@test
PORT=3000
API_URL=http://localhost:8080
@production
PORT=80
API_URL=https://api.example.com
```

| line | meaning |
| --- | --- |
| `@test` | opens a block for one profile or several, as in `.monkeys` |
| `PORT=3000` | a key and its value, for every profile of the block above it |
| `# ...` | a comment |

There is no `+` line: the namespace is the project's, and a profile named
here has to be one `.monkeys` declares. The value is everything after the
`=`, kept as it is, with no quoting, no `${OTHER}` expansion and no second
line. That is the part of the dotenv grammar every library agrees on, and
anything else is refused with its line number rather than read one library's
way.

### One file for each key

A key is either a secret or a value, and the file it is in says which. The
same key in both files for one profile is a conflict: `run` refuses before
running anything, `doctor` says `both files`, and `set` refuses to write a
key the other file already holds, naming the other form. A value is never
looked up in the vault, and a secret is never read from the file.

### Who writes it

`set --public` writes a value under a profile's block, creating the file the
first time. `remove` deletes one. `unpack` writes the values a bundle
carries, next to the `.monkeys` it writes, and `kill` writes the lines of a
`.env` file you answered public for. `run` puts every value of the
profile into the command's environment, and `preview` and `doctor` show them
as they are, since they are public.

## *.monsecrets

A bundle, `a.monsecrets` unless you name it, is one or more profiles with
their keys and secrets in a single encrypted file. `pack` writes one and
`unpack` reads it, and that is the only way a secret leaves the vault.

### Format

Two lines of text:

```
monkeys bundle 1 scrypt 17 8 1
<salt and sealed bytes, base64>
```

The first line names the format and the scrypt cost the key was derived with,
log2 N, r and p, so a bundle keeps opening after the default cost rises. The
second is the salt followed by the sealed bytes, in
base64. Inside, the bundle keeps the
shape of the `.monkeys` file, namespace line and blocks, so `unpack` can write
the file back and store each secret under its profile. When the project has a
`.monvalues` file, its blocks for the packed profiles follow, after a line
that says `.monvalues`, so `unpack` writes that file too; a bundle without
that line is one written before values existed, and still opens.

### Security

The sealed bytes are
[ChaCha20-Poly1305](https://en.wikipedia.org/wiki/ChaCha20-Poly1305), the
AEAD of [RFC 8439](https://www.rfc-editor.org/rfc/rfc8439) that TLS 1.3,
WireGuard and OpenSSH use. A bundle that has been altered fails to open rather than opening
wrong, and a wrong passphrase fails the same way.

The key is derived from the passphrase with
[scrypt](https://en.wikipedia.org/wiki/Scrypt) ([RFC
7914](https://www.rfc-editor.org/rfc/rfc7914)) and a fresh 16-byte salt each
time, at N = 2^17, r = 8, p = 1. Deriving it costs 128 MiB of memory and a fraction of a
second, once for `pack` and once for `unpack`; that memory is what keeps a
guess from being cheap to run in parallel. The passphrase is the weakest part,
so it goes by another route than the file.

A header that asks for a cost outside a fixed range is refused before any
work is done, so a crafted file cannot make `unpack` run for hours.

### Sharing one

The file is safe to send over whatever you already use, and the passphrase
goes another way. `unpack` deletes the bundle once it has done its job; `pack`
writes it to `/tmp`, outside any repository. [Sharing a
profile](/docs/sharing-a-profile) walks through it. A bundle written before a
`rename` still carries the old name, and unpacks to it.

### If one is committed

A bundle has no reason to be in a repository, and `.monkeys` needs no ignore
rule, since it is meant to be committed. If a bundle is committed by mistake
anyway, what leaked is a sealed file: without the passphrase it is noise, and
the fix is to delete it and change the passphrase you would have sent.

# Commands

| command | what it does |
| --- | --- |
| `monkeys set <KEY> [--clipboard]` | read a secret and store it |
| `monkeys set --public <KEY>` | write a plain value into `.monvalues` |
| `monkeys set [@profile] [--all]` | prompt for each key the profile lacks |
| `monkeys remove <KEY>` | delete one secret |
| `monkeys remove @profile[,profile...]` | delete every secret of those profiles |
| `monkeys remove +namespace` | the same for every profile under a namespace |
| `monkeys rename @old @new` | move a profile to a new name, in the vault and the file |
| `monkeys rename +old +new` | the same for every profile under a namespace |
| `monkeys run <KEY[,KEY...]> <command>` | run a command with those secrets in its environment |
| `monkeys run <command>` | the same, with the keys a `.monkeys` file lists |
| `monkeys pack [path] [--open] [--only ...]` | the profiles as one encrypted `a.monsecrets` |
| `monkeys unpack <name> [directory]` | store its secrets, write its `.monkeys` |
| `monkeys kill` | move the `.env` files here into the vault, `.monkeys` and `.monvalues` |
| `monkeys fill @a --with @b` | give `@a` the keys it lacks, from `@b` |
| `monkeys list` | the whole vault, as blocks by profile |
| `monkeys preview [KEY[,KEY...]]` | print each secret masked, with its length |
| `monkeys doctor [--short]` | what each profile has and lacks |
| `monkeys export [KEY[,KEY...]]` | vault lookup lines, to paste into a startup file |

Every command takes a leading `@profile`, one the file declares;
`@namespace.profile` reaches a profile from anywhere, and a bare `@` means no
profile. Where several keys or profiles go, they are joined
with commas, `DATABASE_URL,STRIPE_SECRET_KEY` and `@test,production`, so one
word is one list. Giving no key means every key for `preview` and `export`, or the
project's keys inside a project. `run` asks to be told, since the keys are how
it knows what to check for and what to leave out.

Output is coloured only when it is going to a terminal, and never for
`export`, whose output a shell reads. `NO_COLOR` turns colour
off, `CLICOLOR_FORCE` turns it on for a pipe, and an empty value for either
counts as unset.

`run`, `export` and `pack` each check every key before doing anything, so a
key you never stored stops them with nothing done. A command cannot start with
half of its secrets, a startup file cannot ask for a secret that is not there,
and a bundle cannot carry half of a profile.

## set

```sh
monkeys set [@profile] <KEY> [--clipboard]
monkeys set --public [@profile] <KEY> [--clipboard]
monkeys set [@profile] [--all]
```

Reads a secret and stores it under the key. On a terminal it prompts, and what
you paste is not echoed:

```sh
monkeys set OPENROUTER_API_KEY
```

> ```
> Secret:
> stored OPENROUTER_API_KEY
> give it to a command with:
>   monkeys run OPENROUTER_API_KEY <command>
> ```

`--clipboard` takes the secret from the clipboard instead, through whichever
tool the desktop has, `pbpaste`, `wl-paste`, `xclip` or `xsel`, so a key
copied from a provider's console goes straight in:

```sh
monkeys set GITHUB_TOKEN --clipboard
```

When standard input is not a terminal, the secret is read from there, which
is how a script stores one:

```sh
cat token.txt | monkeys set GITHUB_TOKEN
```

Inside a project the key is stored under the project's profile, so `monkeys
set STRIPE_SECRET_KEY` there writes `foo.test/STRIPE_SECRET_KEY`. A leading
`@profile` picks another, `@namespace.profile` one of another project, and a
bare `@` no profile.

A key you already stored is replaced, and nothing says so.

### Walking a profile

With no key, inside a project, `set` walks the profile's keys in the order the
file lists them and prompts for each one that has no secret yet. An empty
answer skips that key. At the end it shows the profile the way `doctor` does,
with what each key got, and exits non-zero while anything is still missing:

```sh
monkeys set
```

> ```
> DATABASE_URL:
> STRIPE_SECRET_KEY:
> @test  default
>   ✓ DATABASE_URL  stored
>   ✗ STRIPE_SECRET_KEY  skipped
> ```

A leading `@profile` walks that profile instead, one at a time; `@test,production`
is refused. `--all` prompts for every key, and a key that already has a secret
shows its mask in the prompt so Enter keeps it:

```sh
monkeys set --all
```

> ```
> DATABASE_URL (al...e 18, Enter keeps):
> STRIPE_SECRET_KEY (br...e 18, Enter keeps):
> @test  default
>   ✓ DATABASE_URL  kept
>   ✓ STRIPE_SECRET_KEY  stored
> ```

The walk reads from the terminal only. With standard input piped, or with
`--clipboard`, it says so and stores nothing; both of those take one key.
Outside a project there is nothing to walk, and `monkeys set` with no key says
a key is required.

Storing is a human's job. An agent that types a secret puts it in its own
context before it reaches the vault, so the skill tells it to ask instead.

### --public

`--public` writes a value that is not secret, `PORT=3000` and the like, into
the project's `.monvalues` file instead of the vault. It prompts with
`Value:` and echoes what you type, since the value will be committed, and
from a pipe it reads the value the same way:

```sh
echo 3000 | monkeys set --public PORT
echo 80 | monkeys set --public @production PORT
```

> ```
> wrote PORT=3000 to .monvalues for @test
> wrote PORT=80 to .monvalues for @production
> ```

The line goes into the block that is that profile's alone, or into a new
block at the end, and the file is created the first time. A value the
profile already has is replaced in place. A key the file holds for several
profiles together is refused, since replacing it would change them all;
split the block by hand.

`--public` only works inside a project, because a value has nowhere to go
without `.monkeys`. It refuses a key that `.monkeys` lists as a secret for
the profile, and plain `set` refuses a key that `.monvalues` holds as a
value, each naming the other form:

```sh
monkeys set PORT
```

> ```
> monkeys: PORT is a value in .monvalues for @test; replace it with monkeys set --public PORT, or remove it there first
> ```

Turning one into the other is `remove` and then `set`, so a secret never
becomes a committed line by accident.

## remove

```sh
monkeys remove [@profile] <KEY>
monkeys remove @profile[,profile...]
monkeys remove +namespace
```

Deletes one secret from the vault. Inside a project the key is the project's;
`@` reaches one with no profile from there:

```sh
monkeys remove OPENROUTER_API_KEY
monkeys remove @ TYPESAFE_API_KEY
```

The `.monkeys` file is not touched: a project still lists the key, and
`doctor` reports it missing until someone stores a secret for it again.

A key that `.monvalues` holds as a value for the profile is deleted from that
file instead, since the file says which of the two it is:

```sh
monkeys remove API_URL
```

> ```
> removed API_URL from .monvalues for @test
> ```

A value the file sets for several profiles together is refused, the way
`set --public` refuses it, and a key that is in both files is refused until
it is in one.

A profile on its own, with no key, removes every secret stored under it, and a
comma list removes several. The names are all resolved before anything is
deleted, so a typo in the second name leaves the first untouched:

```sh
monkeys remove @test,production
```

> ```
> removed @test: DATABASE_URL, STRIPE_SECRET_KEY
> removed @production: DATABASE_URL, SENTRY_DSN, STRIPE_SECRET_KEY
> ```

A namespace removes every profile under it, declared in a file or not:

```sh
monkeys remove +foo
```

> ```
> removed @foo.production: DATABASE_URL, SENTRY_DSN, STRIPE_SECRET_KEY
> removed @foo.test: DATABASE_URL, STRIPE_SECRET_KEY
> ```

Neither form touches `.monkeys` or `.monvalues`: a project still declares the
profile, and `doctor` reports every key of it missing. A bare `@` is no profile
and is refused, so the secrets with no profile go one key at a time.

## rename

```sh
monkeys rename @old @new
monkeys rename +old +new
```

Moves every secret stored under a profile to a new name, and inside a project
rewrites the `@` lines of `.monkeys` to match, so the vault and the file change
together. Old name first, then new, the way `mv` reads:

```sh
monkeys rename @staging @preview
```

> ```
> moved @staging to @preview: DATABASE_URL, STRIPE_SECRET_KEY, SENTRY_DSN
> rewrote .monkeys: @staging is now @preview
> rewrote .monvalues: @staging is now @preview
> ```

A `.monvalues` next to the file has its `@` lines rewritten the same way, so a
value the old profile had keeps its profile. A namespace rename leaves that
file alone, since its profiles are named without the namespace.

Inside a project both names are the project's, and a prefix that fits only one
declared profile is enough for the old one, `@stag`. From anywhere, by full
name, `monkeys rename @foo.staging @foo.preview` moves the secrets and leaves
every file alone, since none is in reach; a project that names the old profile
then has `doctor` report it missing until its file is edited or the name is
moved back.

A namespace is renamed the same way, for every profile under it, declared in
the file or not, and the `+` line of the project's file with it:

```sh
monkeys rename +foo +bar
```

> ```
> moved @foo.production to @bar.production: DATABASE_URL, STRIPE_SECRET_KEY, SENTRY_DSN
> moved @foo.test to @bar.test: DATABASE_URL, STRIPE_SECRET_KEY
> rewrote .monkeys: +foo is now +bar
> ```

A target that already holds a key is refused, so a rename never merges two
profiles:

> ```
> monkeys: @preview already holds DATABASE_URL; a rename never merges two profiles. To merge, fill @preview --with @staging, then remove what @staging still holds
> ```

The vault has no transaction, so the secrets move one key at a time, stored
under the new name and then removed from the old. At the first failure it
stops, names the keys that moved and the one that did not, and leaves the file
as it was; the file is rewritten only after the last key moved. A bare `@` is
no profile and is neither a source nor a target; a key moves into or out of
the keys with no profile through `fill` or `set`. No secret is printed.

## run

```sh
monkeys run [@profile] <KEY[,KEY...]> <command> [argument...]
monkeys run [@profile] --all <command> [argument...]
monkeys run <command> [argument...]                    # inside a project
```

Runs the command with the named secrets in its environment, and nowhere else.
Nothing in the line holds a secret, so nothing you write can spill one:

```sh
monkeys run OPENROUTER_API_KEY ./hello.sh
monkeys run OPENROUTER_API_KEY,GITHUB_TOKEN ./deploy
```

Once every secret is in place, `run` stays between the command and your
terminal to redact what comes back; the exit status and the signals are the
command's own.

### Inside a project

In a directory that holds a `.monkeys` file, or below it within the checkout,
`run` takes only the command and reads the file's keys from the default
profile. A leading `@profile` picks another declared one:

```sh
monkeys run ./hello.sh
monkeys run npm run dev
monkeys run @production ./deploy
```

A key the file already lists is refused rather than run as a program:

```sh
monkeys run STRIPE_SECRET_KEY ./hello.sh
```

> ```
> monkeys: ~/foo/.monkeys already lists STRIPE_SECRET_KEY for @test
> inside a project, run takes only the command: monkeys run <command>
> ```

The profile's values from `.monvalues`, when the project has one, go into the
environment as well, straight from the file:

```sh
monkeys run sh -c 'echo "$API_URL on port $PORT"'
```

> ```
> http://localhost:8080 on port 3000
> ```

A key that is in both files for the profile stops the run before anything
happens:

> ```
> monkeys: PORT is both a key in .monkeys and a value in .monvalues for @test
> a key lives in one file or the other; remove it from one of them
> ```

### --all

`--all` means every key stored under the profile, listed or not, for when you
would rather not say which:

```sh
monkeys run --all ./bench
```

Outside a project that is every key with no profile, which is the wide end
of the tool. Name the keys the command reads when you can.

### When a secret is missing

A key you have not stored a secret for stops the run before it starts, and
says where it is missing from:

```sh
monkeys run OPENROUTER_API_KEY,ANTHROPIC_API_KEY ./hello.sh
```

> ```
> monkeys: ANTHROPIC_API_KEY is not stored yet
> nothing ran. a human has to store it, then try again:
>   monkeys set ANTHROPIC_API_KEY
> ```

Inside a project the message names the profile, and the `set` it asks for
works from any directory:

> ```
> monkeys: STRIPE_SECRET_KEY is not stored yet in @foo.test
> nothing ran. a human has to store it, then try again:
>   monkeys set @foo.test STRIPE_SECRET_KEY
> ```

That message is written to be passed on. An agent that meets it knows which
keys are missing, that nothing happened, and what a human has to store.

### Where the variable is expanded

`run` sets the variable for the command it starts, so that command is what
expands it. Written into the `monkeys run` line itself, your own shell gets
there first, and yours does not have the secret:

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

A variable the shell already exported is overridden for that command. Keys
you leave out are passed through untouched.

### What comes back

A stored secret in the command's output comes back as `[redacted KEY]`:

```sh
monkeys run OPENROUTER_API_KEY sh -c 'echo "key=$OPENROUTER_API_KEY"'
```

> ```
> key=[redacted OPENROUTER_API_KEY]
> ```

That is the reflex this exists for. An agent that meets an empty variable will
`echo` it, and now the echo says which secret was there and nothing else. The
output is streamed as it arrives: a byte is held back only while it could
still be the start of a secret, and on a terminal that moment shows as `*`
until the next byte settles it.

It catches the secret written whole or in pieces, on stdout or stderr. It
does not catch the secret transformed, so `echo $KEY | base64` goes through;
this is for the reflex, not for someone trying.

A short secret is redacted wherever it appears, so store secrets here and keep
`PORT=3000` in `.monvalues`, whose values are public and pass through
untouched.

### --no-redact

`--no-redact` turns redaction off and runs the command in `monkeys`'s place,
for the one case that needs the secret in the output, such as writing it into
a file a program will read:

```sh
monkeys run --no-redact OPENROUTER_API_KEY envsubst < template > config
```

### A shell with a profile

`monkeys run @production zsh` hands a whole profile to one shell, which forgets it on
exit. That is the way to work with a profile for a while without putting it
into every shell you open.

## pack

```sh
monkeys pack [path] [--open] [--only [KEY[,KEY...]] [@profile[,profile...] [KEY[,KEY...]]]...]
```

Writes a project's secrets as one encrypted file, the only way they leave the
vault. With no arguments it takes every profile the `.monkeys` file declares:

```sh
monkeys pack
```

> ```
> Passphrase:
> Again:
> wrote /tmp/a.monsecrets: +foo @test,production @production, 5 secrets
> ```

The file goes to `/tmp`, which is never inside a repository, and the
message shows the path. A path before `--only` puts it elsewhere: a directory gets `a.monsecrets` inside it, and a file path is used as
given, with `.monkeys` added when missing.

```sh
monkeys pack ~/Desktop
monkeys pack ~/Desktop/for-sam
```

> ```
> wrote ~/Desktop/a.monsecrets: +foo @test,production @production, 5 secrets
> wrote ~/Desktop/for-sam.monsecrets: +foo @test,production @production, 5 secrets
> ```

It carries the project's namespace, each profile's name, the keys the project
lists for it, and their secrets, sealed with ChaCha20-Poly1305 under a key
scrypt derives from the passphrase. When the project has a `.monvalues`
file, the values of the packed profiles ride along whole, since they are
public anyway, and the message counts them:

> ```
> wrote /tmp/a.monsecrets: +foo @test, 2 secrets, 2 values
> ```

One bundle carries one project. The file is safe to send over whatever you
already use; the passphrase goes another way.

`--open` then reveals the file, in Finder with the file selected, or its
folder through `xdg-open` on Linux, since the next thing to do with a bundle
is to drag it somewhere.

A pack with a secret still missing refuses, since a bundle that fills half a
profile is a bug for whoever receives it.

### --only

`--only` says which profiles and keys, and reads the way the file is written:
a `@profile` opens a block, `@a,b` opens one for several profiles at once, and
the keys after it belong to every profile in that block. A block with no keys
after it goes whole; keys before any `@` come from the default profile, the
first the file mentions. That is how a teammate gets test and never
production, or one key on its own:

```sh
monkeys pack --only @test
monkeys pack shared --only @test @production
monkeys pack --only DATABASE_URL
monkeys pack --only @test,production DATABASE_URL
monkeys pack --only @test DATABASE_URL @production SENTRY_DSN
```

> ```
> wrote /tmp/a.monsecrets: +foo @test, 2 secrets
> wrote shared.monsecrets: +foo @test @production, 5 secrets
> wrote /tmp/a.monsecrets: +foo @test, 1 secret
> wrote /tmp/a.monsecrets: +foo @test,production, 2 secrets
> wrote /tmp/a.monsecrets: +foo @test @production, 2 secrets
> ```

The bundle keeps that shape, block for block, and `unpack` writes it back as
the project file. The path goes before `--only`, which takes the rest of
the line. A key a profile does not list is refused rather than left
out.

Outside a project, `--only @foo.test` names a profile in full, and a bundle
made there carries its profiles under their full names, with no `+` line.

The passphrase is read from standard input when it is not a terminal, for the
rare script that needs to.

## unpack

```sh
monkeys unpack <name> [directory] [--keep]
```

Reads a bundle, stores its secrets in your vault under each profile, writes
the profiles and keys as a `.monkeys` file, and deletes the bundle:

```sh
monkeys unpack a
```

> ```
> Passphrase:
> wrote .monkeys: +foo @test,production @production, 3 keys
> stored foo.test/DATABASE_URL, foo.production/DATABASE_URL, foo.test/STRIPE_SECRET_KEY, foo.production/STRIPE_SECRET_KEY
> stored foo.production/SENTRY_DSN
> removed a.monsecrets
> ```

`<name>` is the bundle, with or without its `.monsecrets` suffix; a path works
too. The bundle is deleted only once every secret is stored and the file is
written, since by then it has done its job and a copy left behind is one more
thing to lose. `--keep` leaves it where it was, for a bundle you are handing
on to someone else.

The file goes at the root of the git checkout, the way `.gitignore` sits at
the root, so `monkeys run` works from any directory in it. Outside a checkout
it goes in the current directory, and a second argument names the directory
outright. When a `.monkeys` file is already there, `unpack` adds a block at
the end for the keys the file does not yet list, grouped the way the bundle
groups them, and leaves the rest of the file alone. A file that names another
project on its `+` line refuses the bundle, and the bundle stays.

A bundle that carries values writes `.monvalues` next to `.monkeys` the same
way, adding the values the file does not have and leaving the ones it has:

> ```
> wrote .monkeys: +foo @test, 2 keys
> wrote .monvalues: 2 values
> stored foo.test/DATABASE_URL, foo.test/STRIPE_SECRET_KEY
> removed /tmp/a.monsecrets
> ```

The passphrase is read from standard input when it is not a terminal.

## kill

```sh
monkeys kill
```

Moves a project's dotenv files into monkeys and deletes them. It reads `.env`,
`.env.local` and every `.env.<profile>` in the current directory, asks one
question per key, secret or public, and writes the answers where they belong:
a secret's key into `.monkeys` with the secret in the vault, a public line
into `.monvalues` as it is.

```sh
monkeys kill
```

> ```
> Namespace, +name (Enter for none): foo
> Profile for .env [test]:
> DATABASE_URL @test,@production  [s]ecret or [p]ublic? s
> STRIPE_SECRET_KEY @test  [s]ecret or [p]ublic? s
> PORT @test,@production  [s]ecret or [p]ublic? p
>   public PORT=3000 for @test, into .monvalues
>   public PORT=80 for @production, into .monvalues
> SENTRY_DSN @production  [s]ecret or [p]ublic? s
> wrote .monkeys: +foo @test,production @test @production, 3 keys
> stored @test: DATABASE_URL, STRIPE_SECRET_KEY
> stored @production: DATABASE_URL, SENTRY_DSN
> public @test: PORT
> public @production: PORT
> removed .env, .env.production
> a .gitignore line for them is dead now and can go; monkeys leaves that file alone
> ```

That run started from `.env` and `.env.production` and left this behind:

```monkeys
+foo
@test,production
DATABASE_URL
@test
STRIPE_SECRET_KEY
@production
SENTRY_DSN
```

```monkeys
@test
PORT=3000
@production
PORT=80
```

The files map to profiles the way dotenv already names them: `.env` and
`.env.local` go to the default profile, the first one in `.monkeys` when
the file exists and otherwise the one asked for, and `.env.<name>` goes to
`@<name>`. A key found in several files gets each file's value under that
file's profile, and its line in `.monkeys` lists those profiles together.
`.env.example` is left alone, since `.monkeys` is what it was standing in
for.

The secret answer is the default; Enter takes it. The value is shown only
for a public answer, since that is the moment it becomes a line in a file
that gets committed. A key the project already has, as a secret in the vault,
a key in `.monkeys`, or a value in `.monvalues`, asks before it is replaced,
and Enter keeps what is there; asked for the other kind, it is kept without
asking and named in the summary, since turning one kind into the other is
`remove` and then `set`.

The grammar is the part of dotenv every library reads the same way: `KEY=value`,
`export KEY=value`, a value in single or double quotes with the quotes
stripped, `#` comment lines and blank lines. A value that spans lines, one that
expands another variable with `${...}`, or an unquoted one followed by a `#`
comment is refused with its file and line, and nothing is written until every
file parses:

> ```
> monkeys: .env:2: DATABASE_URL expands another variable; monkeys keeps a value as it is; nothing was written
> ```

When no `.monkeys` exists yet, `kill` asks for a namespace once, Enter for
none, and writes the file at the root of the git checkout, where `unpack`
writes it. When one exists, its `+` line and its profiles stand, and the
keys are added to it the way `unpack` adds them. The dotenv files are
deleted only after every secret is stored and both files are written. The
`.gitignore` lines that kept them out of git are left for you, and the last
line says so. `kill` asks its questions on the terminal, so it refuses to run
with its input piped.

## fill

```sh
monkeys fill @profile --with @profile
```

Gives the first profile the keys it lacks, taking the secrets from the second.
Two profiles of one project usually share most of their secrets, and the
second is filled from the first:

```sh
monkeys fill @production --with @test
```

> ```
> filled @production from @test: STRIPE_SECRET_KEY
> kept 1 @production already had
> still missing in @production: SENTRY_DSN
> ```

`fill` moves only the keys the target lacks and never touches a secret it
already holds, so it is safe to run twice. It names every key it moved, since
a production profile filled from test is a decision to see written down, and
it exits non-zero while anything is still missing. No secret is printed.

Inside a project the keys are the ones the file lists for the target;
elsewhere they are whatever the source holds. Either side may be another
project's profile, `@bar.test`, which is how a secret shared by two projects
is stored once and copied.

## list

```sh
monkeys list
```

Prints the whole vault in the shape of a `.monkeys` file, one block per
profile, with every profile under its full name and the keys with no profile
first, under a bare `@`:

```sh
monkeys list
```

> ```monkeys
> @
> TYPESAFE_API_KEY
>
> @foo.production
> DATABASE_URL
> SENTRY_DSN
>
> @foo.test
> DATABASE_URL
> STRIPE_SECRET_KEY
> ```

Two profiles that share a block in a project's file appear here as two
blocks, since the vault holds a secret per profile. `list` reads the whole
vault, so it shows every project at once, and prints nothing when the vault
is empty.

## preview

```sh
monkeys preview [@profile] [KEY[,KEY...]]
```

Answers the question you usually have, which is whether the right secret is in
there, without printing it:

```sh
monkeys preview
```

> ```
> GITHUB_TOKEN        gh...f 40
> OPENROUTER_API_KEY  sk...2 73
> ```

It shows the first two characters, the last one, and the length. A secret is
masked whole whenever fewer than five characters would stay hidden, so nothing
under eight characters long gives any of itself away:

```sh
monkeys preview SHORT_ONE
```

> ```
> SHORT_ONE  ... 6
> ```

A length and a two-character prefix are enough to tell a secret pasted whole
from one that lost a character on the way, or one provider's from another's.

With no keys, `preview` shows every key in the profile: those with no profile
outside a project, the file's keys inside one. A value from `.monvalues` is
shown as it is, after the secrets, since it is public:

```sh
monkeys preview
```

> ```
> DATABASE_URL       po...t 29
> STRIPE_SECRET_KEY  sk...p 34
> PORT               3000
> API_URL            http://localhost:8080
> ```

## doctor

```sh
monkeys doctor [--short]
```

Reads the whole `.monkeys` file and shows every profile with what it has and
lacks, in colour on a terminal. It exits non-zero while anything is missing:

```sh
monkeys doctor
```

> ```
> @test  default
>   ✓ DATABASE_URL
>   ✓ STRIPE_SECRET_KEY
> @production
>   ✓ DATABASE_URL
>   ✗ STRIPE_SECRET_KEY
>   ✗ SENTRY_DSN
> ```

A value from `.monvalues` counts as present and is shown with its value,
and a key that is in both files is marked as such, since `run` will refuse it:

> ```
> @test  default
>   ✓ DATABASE_URL
>   ✓ STRIPE_SECRET_KEY
>   ✗ PORT  also a value in .monvalues
>   ✓ API_URL=http://localhost:8080
> ```

### --short

`--short` says only what is wrong, one line per profile with a problem, and
nothing at all when there is none, which is the form to hand a script or an
agent:

```sh
monkeys doctor --short
```

> ```
> missing @production: STRIPE_SECRET_KEY,SENTRY_DSN
> ```

A key in both files gets its own line, `both files @test: PORT`.

## export

```sh
monkeys export [@profile] [KEY[,KEY...]]
```

For a secret that every shell should carry from startup, `export` writes the
lines and you paste them into your startup file:

```sh
monkeys export TYPESAFE_API_KEY
```

On macOS:

> ```
> export TYPESAFE_API_KEY="$(security find-generic-password -s monkeys -a TYPESAFE_API_KEY -w)"
> ```

On Linux:

> ```
> export TYPESAFE_API_KEY="$(secret-tool lookup service monkeys account TYPESAFE_API_KEY)"
> ```

No secret is in either line. Each asks the vault when the shell starts, the
way you would have written it by hand, so a startup file written on one
machine is for that machine's vault. With no keys, inside a project, it writes
one line per key the file lists.

`monkeys` writes nothing into your startup file for you: a secret that every
process on the machine inherits is a decision to make with the file open.

The keychain treats `security` as its own program, so the first shell that
runs the line asks once whether to allow it. Answer Always Allow and it stays
quiet.

# Sharing a profile

A project's secrets travel as one encrypted file: `pack` on one machine,
`unpack` on the other. The file is safe to send over whatever you already
use; the passphrase goes another way.

On the machine that has the secrets, inside the checkout:

```sh
monkeys pack --only @test
```

> ```
> Passphrase:
> Again:
> wrote /tmp/a.monsecrets: +foo @test, 2 secrets
> ```

Send that file. On the other machine, anywhere inside their
checkout:

```sh
monkeys unpack ~/Downloads/a.monsecrets
```

> ```
> Passphrase:
> wrote .monkeys: +foo @test, 2 keys
> stored foo.test/DATABASE_URL, foo.test/STRIPE_SECRET_KEY
> removed /Users/them/Downloads/a.monsecrets
> ```

Their vault now holds the secrets under the same profile, and `monkeys run
./hello.sh` works for them the way it works for you. When they cloned the
repository, the `.monkeys` file was already there, and `unpack` leaves it as
it was, adding only keys it does not list.

# Caveats

### What redaction can and cannot do

An agent that sets out to see a secret can see it. `run` hands the secret to
a process, and a process can do what it likes with what it holds: encode it,
split it, write it somewhere and read it back. Redaction catches the secret
written out as it is, which is what a reflex produces, and nothing here claims
more than that.

That is enough, because the reflex is the whole problem. An agent does not
read `.env` out of curiosity. It reads it because a variable was empty, the
task was stuck, and `cat .env` was the shortest path back to the task. Take the
shortest path away and give it a shorter one, and the urge goes with it: `run`
puts the secret where the task needs it, a missing key comes back as a message
that says what to ask for, `preview` and `doctor --short` answer "is it there"
without reading anything. The agent gets on with the task. What remains after
that is intent, and intent is a question for whoever runs the agent.

The same holds for people. A secret shared with a teammate stops being a paste
into a chat and becomes `pack` and `unpack`, sealed in transit and landing in
that person's vault. And the bookkeeping a project keeps about its secrets, a
`.env` nobody commits, a `.env.example` that drifts from it, a `.gitignore` line
to keep the two apart, collapses into one committed `.monkeys` file that says
what is needed and holds nothing.
