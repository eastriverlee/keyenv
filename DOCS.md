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
@foo
OPENROUTER_API_KEY
STRIPE_SECRET_KEY

$ monkeys set OPENROUTER_API_KEY    # the secret goes into the vault, once
Secret:

$ monkeys run ./hello.sh            # the command gets them, and nothing else does
$ monkeys pack                      # to share: one encrypted file
$ monkeys unpack a.monkeys          # on their machine, into their vault
```

The `.monkeys` file replaces all three of `.env`, `.env.example` and the
`.gitignore` line, and it is the one that is committed. One binary for macOS
and Linux does the rest: no runtime, no service, and no vault of its own,
since the login keychain and the Secret Service are already there.

## What it is not

Not a secret manager with a server or an audit log. Not a wall against an
agent that sets out to read a secret; it removes the reflex, which is the
everyday problem. Not a place for `PORT=3000`, which stays in the repository.

## Where to go next

[Quickstart](/docs/quickstart) spends a first secret in three commands,
[Concepts](/docs/concepts/profile) defines the six words the reference uses,
and [Commands](/docs/commands) has one page per command.

# Concepts

## Profile

A profile is a named set of secrets. Every secret `monkeys` stores sits under
one, as `<profile>/<KEY>`, and a project's `.monkeys` file says which profile
its keys belong to:

```
@foo
DATABASE_URL
STRIPE_SECRET_KEY
OPENROUTER_API_KEY
```

The profile's name is the project's and its secrets are yours. Everyone who
clones the repository gets the same profile and the same keys, and each of
them fills their own vault, so a `.monkeys` file can be committed and a vault
never has to be.

### The default profile

The first profile a `.monkeys` file mentions is the default, the one every
command uses in that project when none is given. Inside the checkout, `run`
takes only the command, `set` stores under the profile, and `preview` with no
keys shows the file's keys:

```sh
monkeys run ./hello.sh
monkeys set STRIPE_SECRET_KEY        # stores foo/STRIPE_SECRET_KEY
monkeys preview
```

`list` stays global and shows the prefixes, so you can see which project each
secret belongs to.

### Several profiles

A profile line can name several profiles, and a file can hold several blocks:

```
@test.foo,foo
DATABASE_URL
STRIPE_SECRET_KEY
@foo
SENTRY_DSN
```

A profile's keys are those of every block that lists it: both profiles here
need `DATABASE_URL` and `STRIPE_SECRET_KEY`, and `foo` also needs
`SENTRY_DSN`. The default is still the first, `test.foo`, so production is
something you say.

A secret missing in one profile stops only that profile, and only when it is
used: `foo` can be half filled while `test.foo` runs. `doctor` shows the whole
picture.

### Choosing a profile

Any command takes a leading `@profile`, which picks another declared one. A
prefix that fits only one of them is enough, the way a short git hash is:

```sh
monkeys run @foo ./deploy
monkeys set @foo SENTRY_DSN
monkeys run @test ./hello.sh        # test.foo, by its prefix
```

A profile the file does not declare is refused with the declared ones listed,
and a prefix that fits several is refused with those, so a typo never becomes
a new profile.

### Naming profiles

Profile names take letters, digits, `_`, `-` and `.`. A dotted name in the
style of a bundle identifier keeps two projects' test apart in one vault. Two
parts, `test.foo`, is enough for most; a third, `test.foo.lee`, is for a vault
that holds many projects and collides at two. A single word does for a profile
nothing else will collide with.

### No profile

A key stored outside any project has no profile and needs no `@`. Those are
the global keys, where a secret that belongs to you rather than to a project
lives, such as the one a tool you start from anywhere reads:

```sh
monkeys set TYPESAFE_API_KEY
monkeys run TYPESAFE_API_KEY claude
```

A project profile never reads from the global keys. A key missing in `@foo`
is missing there even when a global copy exists, so a project cannot quietly
pick up a secret meant for another.

Inside a project every command is scoped to that project's profile, so the
global keys are out of reach there: `monkeys run` reads `foo/`, and `monkeys
set TYPESAFE_API_KEY` would write `foo/TYPESAFE_API_KEY`. A bare `@` means no
profile. It sets the project file aside, so keys are given again, and reaches
the global ones without leaving the directory:

```sh
monkeys run @ TYPESAFE_API_KEY claude
monkeys set @ TYPESAFE_API_KEY
monkeys preview @ TYPESAFE_API_KEY
```

It is the same secret either way; the `@` only says which profile to look in
when a file would otherwise decide.

## Key

A key is the name of an environment variable, the `KEY` of `KEY=secret`. It
is what a program reads, what a `.monkeys` file lists, and what every command
takes on its line:

```sh
monkeys set OPENROUTER_API_KEY
monkeys run OPENROUTER_API_KEY ./hello.sh
```

A key takes letters, digits and `_`, and cannot start with a digit, the way a
shell variable cannot. Keys are public: they are committed in `.monkeys`, they
appear in `list` and in every message, and the process `run` starts sees them
as variables. The same key in two profiles is two secrets, and the key alone,
with no profile, is a third.

`monkeys` takes no secret as an argument, only keys, so storing one never
types it: your shell history and the process table both see `monkeys set
GITHUB_TOKEN` and nothing more.

## Secret

A secret is what a key holds: the API key, token or password itself. It goes
into the vault with `set`, comes out only into the environment of a command
`run` starts, and is never printed. What `run` gets back from that command is
searched for it, and it comes back as `[redacted KEY]`.

A secret you store under a key you already stored replaces the old one, and
nothing says so. The previous secret is gone, and the vault keeps no history
to recover it from.

To read a secret in full, open the vault itself, Keychain Access or your
desktop's secret browser, where the decision to look at one is yours and
deliberate. No `monkeys` command prints one.

## Vault

The vault is the operating system's own secret store, and `monkeys` keeps
nothing anywhere else. On macOS it is the login keychain, reached through
Security.framework; on Linux it is whatever answers the Secret Service D-Bus
API, which is gnome-keyring on most desktops and KWallet on KDE, reached
through `secret-tool`. There is no file of `monkeys`'s own to back up, leak
or forget, and the desktop's own tools see everything `monkeys` stores.

### What an item looks like

Each secret is one item carrying two attributes: `service` is `monkeys`, and
`account` is `<profile>/<KEY>`, or `<KEY>` alone for a global key. The label
is `monkeys: ` followed by the account. Deleting an item in the desktop's
tools deletes it for `monkeys`.

On macOS that is a generic password in the login keychain. Search Keychain
Access for `monkeys`, or ask for one by account:

```sh
security find-generic-password -s monkeys -a OPENROUTER_API_KEY
security find-generic-password -s monkeys -a foo/OPENROUTER_API_KEY
```

Items are created with `kSecAttrAccessibleAfterFirstUnlock`, so a shell that
starts while the screen is locked can still read them.

On Linux the same attributes go through `secret-tool`:

```sh
secret-tool lookup service monkeys account foo/OPENROUTER_API_KEY
```

### The keychain prompt on macOS

A binary built from source carries an ad-hoc signature, whose identity is a
hash of the binary itself. A rebuild changes that identity, so the keychain
may ask you to allow access once when the new build first reads an item the
old one stored. The release builds are what `brew` and the install script
give you.

### The Secret Service on Linux

The Secret Service is a desktop session service. Over SSH or in a container
there is usually no session bus and no secret daemon, and `monkeys` fails
saying so. Machines like that want a different mechanism, not this one.

## .monkeys

A project lists the keys it needs once, in a `.monkeys` file next to the
code:

```
@test.foo,foo
DATABASE_URL
STRIPE_SECRET_KEY
@foo
SENTRY_DSN
```

A `@` line names one profile or several, the keys below it belong to those
profiles, and `#` starts a comment. Commit it. It is the secret half of
`.env.example`, and a project keeps one or the other, since two lists of the
same keys drift. The file holds keys and never secrets, which is what makes it
safe to commit.

The file is looked for from the current directory upward, nearest first, and
the search stops at the root of the git checkout, so a file above the checkout
is never read. Outside a checkout only the current directory counts, and where
no file is found the commands take keys on the line, as they do anywhere else.

`unpack` writes the file at the root of the checkout, and `doctor` reads it
whole.

## *.monkeys

A bundle, `a.monkeys` unless you name it, is one or more profiles with
their keys and secrets, sealed with ChaCha20-Poly1305 under a
key scrypt derives from a passphrase. `pack` writes one and `unpack` reads
it, and that is the only way a secret leaves the vault.

The file is two lines of text. The first names the format and the scrypt
cost the key was derived with, so a bundle keeps opening after the default
cost rises; the second is the salt and the sealed bytes, base64. Deriving
the key costs 128 MiB of memory and a fraction of a second, once for `pack`
and once for `unpack`, which is what makes guessing the passphrase
expensive.

The bundle keeps the shape of the `.monkeys` file, block for block, so
`unpack` can write the file back and store each secret under its profile. It
is safe to send over whatever you already use; the passphrase goes another
way, and `unpack` deletes the bundle once it has done its job.

A bundle has no reason to be in a repository, and `.monkeys` needs no ignore
rule, since it is meant to be committed. If a bundle is committed by mistake
anyway, what leaked is a sealed file: without the passphrase it is noise, and
the fix is to delete it and change the passphrase you would have sent.

# Commands

| command | what it does |
| --- | --- |
| `monkeys set <KEY>` | read a secret and store it |
| `monkeys list` | print every stored key |
| `monkeys preview [KEY...]` | print each secret masked, with its length |
| `monkeys remove <KEY>` | delete one secret |
| `monkeys run <KEY>[,<KEY>] <command>` | run a command with those secrets in its environment |
| `monkeys run <command>` | the same, with the keys a `.monkeys` file lists |
| `monkeys export [KEY...]` | vault lookup lines, to paste into a startup file |
| `monkeys pack [name] [--only ...]` | the profiles as one encrypted `name.monkeys` |
| `monkeys unpack <name> [directory]` | store its secrets, write its `.monkeys` |
| `monkeys fill @a --with @b` | give `@a` the keys it lacks, from `@b` |
| `monkeys doctor [--short]` | what each profile has and lacks |

Every command takes a leading `@profile`; a bare `@` means no profile, the
global keys. Giving no key means every key for `preview` and `export`, or the
project's keys inside a project. `run` asks to be told, since the keys are how
it knows what to check for and what to leave out.

Output is coloured only when it is going to a terminal, and never for `list`
or `export`, whose output a script or a shell reads. `NO_COLOR` turns colour
off, `CLICOLOR_FORCE` turns it on for a pipe, and an empty value for either
counts as unset.

`run`, `export` and `pack` each check every key before doing anything, so a
key you never stored stops them with nothing done. A command cannot start with
half of its secrets, a startup file cannot ask for a secret that is not there,
and a bundle cannot carry half of a profile.

## set

```sh
monkeys set [@profile] <KEY>
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

When standard input is not a terminal, the secret is read from there:

```sh
pbpaste | monkeys set GITHUB_TOKEN        # macOS
wl-paste | monkeys set GITHUB_TOKEN       # Linux, Wayland
```

Inside a project the key is stored under the project's profile, so `monkeys
set STRIPE_SECRET_KEY` there writes `foo/STRIPE_SECRET_KEY`. A leading
`@profile` picks another, and a bare `@` the global keys.

A key you already stored is replaced, and nothing says so.

Storing is a human's job. An agent that types a secret puts it in its own
context before it reaches the vault, so the skill tells it to ask instead.

## list

```sh
monkeys list
```

Prints every stored key, one per line, with its profile prefix:

```sh
monkeys list
```

> ```
> TYPESAFE_API_KEY
> foo/DATABASE_URL
> foo/STRIPE_SECRET_KEY
> test.foo/DATABASE_URL
> ```

`list` is global, so it shows which project each secret belongs to. Its
output is never coloured, since a script reads it.

## preview

```sh
monkeys preview [@profile] [KEY...]
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

With no keys, `preview` shows every key in the profile: the global ones
outside a project, the file's keys inside one.

## remove

```sh
monkeys remove [@profile] <KEY>
```

Deletes one secret from the vault. Inside a project the key is the project's;
`@` reaches a global one from there:

```sh
monkeys remove OPENROUTER_API_KEY
monkeys remove @ TYPESAFE_API_KEY
```

The `.monkeys` file is not touched: a project still lists the key, and
`doctor` reports it missing until someone stores a secret for it again.

## run

```sh
monkeys run [@profile] <KEY>[,<KEY>...] <command> [argument...]
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
monkeys run @foo ./deploy
```

A key the file already lists is refused rather than run as a program:

```sh
monkeys run STRIPE_SECRET_KEY ./hello.sh
```

> ```
> monkeys: ~/foo/.monkeys already lists STRIPE_SECRET_KEY for @foo
> inside a project, run takes only the command: monkeys run <command>
> ```

### --all

`--all` means every key stored under the profile, listed or not, for when you
would rather not say which:

```sh
monkeys run --all ./bench
```

Outside a project that is every global key, which is the wide end of the
tool. Name the keys the command reads when you can.

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
> monkeys: STRIPE_SECRET_KEY is not stored yet in @foo
> nothing ran. a human has to store it, then try again:
>   monkeys set @foo STRIPE_SECRET_KEY
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
`PORT=3000` in the repository.

### --no-redact

`--no-redact` turns redaction off and runs the command in `monkeys`'s place,
for the one case that needs the secret in the output, such as writing it into
a file a program will read:

```sh
monkeys run --no-redact OPENROUTER_API_KEY envsubst < template > config
```

### A shell with a profile

`monkeys run @foo zsh` hands a whole profile to one shell, which forgets it on
exit. That is the way to work with a profile for a while without putting it
into every shell you open.

## export

```sh
monkeys export [@profile] [KEY...]
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

## pack

```sh
monkeys pack [name] [--only [KEY...] [@profile[,profile] [KEY...]]...]
```

Writes a project's secrets as one encrypted file, the only way they leave the
vault. With no arguments it takes every profile the `.monkeys` file declares:

```sh
monkeys pack
```

> ```
> Passphrase:
> Again:
> wrote a.monkeys: @test.foo,foo @foo, 5 secrets
> ```

The file is `a.monkeys` unless a word after `pack` names it.
It carries each profile's name, the keys the project lists for it, and their
secrets, sealed with ChaCha20-Poly1305 under a key scrypt derives from the
passphrase. The file is safe to send over whatever you already use; the
passphrase goes another way.

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
monkeys pack --only @test.foo
monkeys pack shared --only @test.foo @foo
monkeys pack --only DATABASE_URL
monkeys pack --only @test.foo,foo DATABASE_URL
monkeys pack --only @test.foo DATABASE_URL @foo SENTRY_DSN
```

> ```
> wrote a.monkeys: @test.foo, 2 secrets
> wrote shared.monkeys: @test.foo @foo, 5 secrets
> wrote a.monkeys: @test.foo, 1 secret
> wrote a.monkeys: @test.foo,foo, 2 secrets
> wrote a.monkeys: @test.foo @foo, 2 secrets
> ```

The bundle keeps that shape, block for block, and `unpack` writes it back as
the project file. The file name goes before `--only`, which takes the rest of
the line. A key a profile does not list is refused rather than left
out.

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
> wrote .monkeys: @test.foo,foo @foo, 3 keys
> stored test.foo/DATABASE_URL, foo/DATABASE_URL, test.foo/STRIPE_SECRET_KEY, foo/STRIPE_SECRET_KEY
> stored foo/SENTRY_DSN
> removed a.monkeys
> ```

`<name>` is the bundle, with or without its `.monkeys` suffix; a path works
too. The bundle is deleted only once every secret is stored and the file is
written, since by then it has done its job and a copy left behind is one more
thing to lose. `--keep` leaves it where it was, for a bundle you are handing
on to someone else.

The file goes at the root of the git checkout, the way `.gitignore` sits at
the root, so `monkeys run` works from any directory in it. Outside a checkout
it goes in the current directory, and a second argument names the directory
outright. When a `.monkeys` file is already there, `unpack` adds a block at
the end for the keys the file does not yet list, grouped the way the bundle
groups them, and leaves the rest of the file alone.

The passphrase is read from standard input when it is not a terminal.

## fill

```sh
monkeys fill @profile --with @profile
```

Gives the first profile the keys it lacks, taking the secrets from the second.
Two profiles of one project usually share most of their secrets, and the
second is filled from the first:

```sh
monkeys fill @foo --with @test.foo
```

> ```
> filled @foo from @test.foo: STRIPE_SECRET_KEY
> kept 1 @foo already had
> still missing in @foo: SENTRY_DSN
> ```

`fill` moves only the keys the target lacks and never touches a secret it
already holds, so it is safe to run twice. It names every key it moved, since
a production profile filled from test is a decision to see written down, and
it exits non-zero while anything is still missing. No secret is printed.

Inside a project the keys are the ones the file lists for the target;
elsewhere they are whatever the source holds.

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
> @test.foo  default
>   ✓ DATABASE_URL
>   ✓ STRIPE_SECRET_KEY
> @foo
>   ✓ DATABASE_URL
>   ✗ STRIPE_SECRET_KEY
>   ✗ SENTRY_DSN
> ```

### --short

`--short` says only what is wrong, one line per profile with a problem, and
nothing at all when there is none, which is the form to hand a script or an
agent:

```sh
monkeys doctor --short
```

> ```
> missing @foo: STRIPE_SECRET_KEY,SENTRY_DSN
> ```

# Sharing a profile

A project's secrets travel as one encrypted file: `pack` on one machine,
`unpack` on the other. The file is safe to send over whatever you already
use; the passphrase goes another way.

On the machine that has the secrets, inside the checkout:

```sh
monkeys pack --only @test.foo
```

> ```
> Passphrase:
> Again:
> wrote a.monkeys: @test.foo, 2 secrets
> ```

Send `a.monkeys`. On the other machine, anywhere inside their
checkout:

```sh
monkeys unpack ~/Downloads/a.monkeys
```

> ```
> Passphrase:
> wrote .monkeys: @test.foo, 2 keys
> stored test.foo/DATABASE_URL, test.foo/STRIPE_SECRET_KEY
> removed /Users/them/Downloads/a.monkeys
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
