# Concepts

## Profiles and the .monkeys file

A project names what it needs once, in a `.monkeys` file next to the code:

```
@foo
DATABASE_URL
STRIPE_SECRET_KEY
OPENROUTER_API_KEY
```

The first line names the profile; the rest are names, and `#` starts a
comment. Commit it. It is the secret half of `.env.example`, and a project
keeps one or the other, since two lists of the same names drift.

The profile's name is the project's and its values are yours. Everyone who
clones the repository gets the same names, and each of them fills their own
keyring, so a `.monkeys` file can be committed and a keyring never has to be.

### Inside a project

In the directory that holds the file, or any below it within the git
checkout, every command is scoped to the profile. `run` takes only the
command, `set` stores under the profile, and `preview` with no names shows
the file's names:

```sh
monkeys run ./hello.sh
monkeys set STRIPE_SECRET_KEY        # stores foo/STRIPE_SECRET_KEY
monkeys preview
```

`list` stays global and shows the prefixes, so you can see which project each
value belongs to.

The file is looked for from the current directory upward, nearest first, and
the search stops at the root of the git checkout, so a file above the checkout
is never read. Outside a checkout only the current directory counts, and where
no file is found the commands take names on the line, as they do anywhere
else.

### Several profiles

A profile line can name several profiles, and a file can hold several blocks:

```
@test.foo,foo
DATABASE_URL
STRIPE_SECRET_KEY
@foo
SENTRY_DSN
```

A profile's names are those of every block that lists it: both profiles here
need `DATABASE_URL` and `STRIPE_SECRET_KEY`, and `foo` also needs
`SENTRY_DSN`. The first profile in the file is the default, the one used when
none is given.

A value missing in one profile stops only that profile, and only when it is
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
style of a bundle identifier keeps two projects' test apart in one keyring.
Two parts, `test.foo`, is enough for most; a third, `test.foo.lee`, is for a
keyring that holds many projects and collides at two. A single word does for
a profile nothing else will collide with.

## No profile

A name stored outside any project has no profile and needs no `@`. Those
are the global names, where a value that belongs to you rather than to a
project lives, such as the key a tool you start from anywhere reads:

```sh
monkeys set TYPESAFE_API_KEY
monkeys run TYPESAFE_API_KEY claude
```

A project profile never reads from the global names. A name missing in `@foo`
is missing there even when a bare copy exists, so a project cannot quietly
pick up a value meant for another.

Inside a project every command is scoped to that project's profile, so the
global names are out of reach there: `monkeys run` reads `foo/`, and
`monkeys set TYPESAFE_API_KEY` would write `foo/TYPESAFE_API_KEY`. A bare `@`
means no profile. It sets the project file aside, so names are
given again, and reaches the unprefixed names without leaving the directory:

```sh
monkeys run @ TYPESAFE_API_KEY claude
monkeys set @ TYPESAFE_API_KEY
monkeys preview @ TYPESAFE_API_KEY
```

It is the same value either way; the `@` only says which profile to look in
when a file would otherwise decide.

## Where values are stored

Each variable is one keyring item carrying two attributes: `service` is
`monkeys`, and `account` is `<profile>/<NAME>`, or `<NAME>` alone for a
global name. The label is `monkeys: ` followed by the account. The same
name in two profiles is two items. Your desktop's own keyring tools see the
same items, and deleting one there deletes it for `monkeys`.

On macOS that is a generic password in the login keychain. Search Keychain
Access for `monkeys`, or ask for one by name:

```sh
security find-generic-password -s monkeys -a OPENROUTER_API_KEY
security find-generic-password -s monkeys -a foo/OPENROUTER_API_KEY
```

Items are created with `kSecAttrAccessibleAfterFirstUnlock`, so a shell that
starts while the screen is locked can still read them.

On Linux the same attributes go to the Secret Service D-Bus API through
`secret-tool`, which is gnome-keyring on most desktops and KWallet on KDE:

```sh
secret-tool lookup service monkeys account foo/OPENROUTER_API_KEY
```

To read a value in full, open Keychain Access or your keyring's own browser,
where the decision to look at a secret is yours and deliberate. No `monkeys`
command prints one.

# Commands

| command | what it does |
| --- | --- |
| `monkeys set <NAME>` | read a value and store it |
| `monkeys list` | print every stored name |
| `monkeys preview [NAME...]` | print each value masked, with its length |
| `monkeys remove <NAME>` | delete one value |
| `monkeys run <NAME>[,<NAME>] <command>` | run a command with those values in its environment |
| `monkeys run <command>` | the same, with the names a `.monkeys` file lists |
| `monkeys export [NAME...]` | keyring lookup lines, to paste into a startup file |
| `monkeys pack [name] [--only ...]` | the profiles as one encrypted `name.monkeys` |
| `monkeys unpack <name> [directory]` | store its values, write its `.monkeys` |
| `monkeys fill @a --with @b` | give `@a` the names it lacks, from `@b` |
| `monkeys doctor [--short]` | what each profile has and lacks |

Every command takes a leading `@profile`; a bare `@` means no profile, the global names.
Naming no name means every name for `preview` and `export`, or the project's
names inside a project. `run` asks to be told, since the names are how it
knows what to check for and what to leave out.

`monkeys` takes no value as an argument, so storing one never types it: your
shell history and the process table both see `monkeys set GITHUB_TOKEN` and
nothing more.

Output is coloured only when it is going to a terminal, and never for `list`
or `export`, whose output a script or a shell reads. `NO_COLOR` turns colour
off, `CLICOLOR_FORCE` turns it on for a pipe, and an empty value for either
counts as unset.

`run`, `export` and `pack` each check every name before doing anything, so a
name you never stored stops them with nothing done. A command cannot start
with half of its secrets, a startup file cannot ask for a value that is not
there, and a bundle cannot carry half of a profile.

## set

```sh
monkeys set [@profile] <NAME>
```

Reads a value and stores it under the name. On a terminal it prompts, and
what you paste is not echoed:

```sh
monkeys set OPENROUTER_API_KEY
```

> ```
> Value:
> stored OPENROUTER_API_KEY
> give it to a command with:
>   monkeys run OPENROUTER_API_KEY <command>
> ```

When standard input is not a terminal, the value is read from there:

```sh
pbpaste | monkeys set GITHUB_TOKEN        # macOS
wl-paste | monkeys set GITHUB_TOKEN       # Linux, Wayland
```

Inside a project the name is stored under the project's profile, so
`monkeys set STRIPE_SECRET_KEY` there writes `foo/STRIPE_SECRET_KEY`. A
leading `@profile` picks another, and a bare `@` the global names.

A name you already stored is replaced, and nothing says so. The previous
value is gone, and the keyring keeps no history to recover it from.

Storing is a human's job. An agent that types a value puts it in its own
context before it reaches the keyring, so the skill tells it to ask instead.

## list

```sh
monkeys list
```

Prints every stored name, one per line, with its profile prefix:

```sh
monkeys list
```

> ```
> TYPESAFE_API_KEY
> foo/DATABASE_URL
> foo/STRIPE_SECRET_KEY
> test.foo/DATABASE_URL
> ```

`list` is global, so it shows which project each value belongs to. Its output
is never coloured, since a script reads it.

## preview

```sh
monkeys preview [@profile] [NAME...]
```

Answers the question you usually have, which is whether the right value is in
there, without printing it:

```sh
monkeys preview
```

> ```
> GITHUB_TOKEN        gh...f 40
> OPENROUTER_API_KEY  sk...2 73
> ```

It shows the first two characters, the last one, and the length. A value is
masked whole whenever fewer than five characters would stay hidden, so nothing
under eight characters long gives any of itself away:

```sh
monkeys preview SHORT_ONE
```

> ```
> SHORT_ONE  ... 6
> ```

A length and a two-character prefix are enough to tell a key pasted whole from
one that lost a character on the way, or one provider's key from another's.

With no names, `preview` shows every name in the profile: the global ones
outside a project, the file's names inside one.

## remove

```sh
monkeys remove [@profile] <NAME>
```

Deletes one value from the keyring. Inside a project the name is the
project's; `@` reaches a global one from there:

```sh
monkeys remove OPENROUTER_API_KEY
monkeys remove @ TYPESAFE_API_KEY
```

The `.monkeys` file is not touched: a project still lists the name, and
`doctor` reports it missing until someone stores it again.

## run

```sh
monkeys run [@profile] <NAME>[,<NAME>...] <command> [argument...]
monkeys run [@profile] --all <command> [argument...]
monkeys run <command> [argument...]                    # inside a project
```

Runs the command with the named values in its environment, and nowhere else.
Nothing in the line holds a secret, so nothing you write can spill one:

```sh
monkeys run OPENROUTER_API_KEY ./hello.sh
monkeys run OPENROUTER_API_KEY,GITHUB_TOKEN ./deploy
```

Once every value is set, `run` stays between the command and your terminal to
redact what comes back; the exit status and the signals are the command's own.

### Inside a project

In a directory that holds a `.monkeys` file, or below it within the checkout,
`run` takes only the command and reads the file's names from the default
profile. A leading `@profile` picks another declared one:

```sh
monkeys run ./hello.sh
monkeys run npm run dev
monkeys run @foo ./deploy
```

A name the file already lists is refused rather than run as a program:

```sh
monkeys run STRIPE_SECRET_KEY ./hello.sh
```

> ```
> monkeys: ~/foo/.monkeys already lists STRIPE_SECRET_KEY for @foo
> inside a project, run takes only the command: monkeys run <command>
> ```

### --all

`--all` means every name stored under the profile, listed or not, for when
you would rather not say which:

```sh
monkeys run --all ./bench
```

Outside a project that is every global name, which is the wide end of the
tool. Name what the command reads when you can.

### When a name is missing

A name you have not stored stops the run before it starts, and says where it
is missing from:

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
values are missing, that nothing happened, and what a human has to store.

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

A variable the shell already exported is overridden for that command. Names
you leave out are passed through untouched.

### What comes back

A stored value in the command's output comes back as `[redacted NAME]`:

```sh
monkeys run OPENROUTER_API_KEY sh -c 'echo "key=$OPENROUTER_API_KEY"'
```

> ```
> key=[redacted OPENROUTER_API_KEY]
> ```

That is the reflex this exists for. An agent that meets an empty variable will
`echo` it, and now the echo says which value was there and nothing else. The
output is streamed as it arrives: a byte is held back only while it could
still be the start of a value, and on a terminal that moment shows as `*`
until the next byte settles it.

It catches the value written whole or in pieces, on stdout or stderr. It does
not catch the value transformed, so `echo $KEY | base64` goes through; this is
for the reflex, not for someone trying.

A short stored value is redacted wherever it appears, so store secrets here
and keep `PORT=3000` in the repository.

### --no-redact

`--no-redact` turns redaction off and runs the command in `monkeys`'s place,
for the one case that needs the value in the output, such as writing it into
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
monkeys export [@profile] [NAME...]
```

For a value that every shell should carry from startup, `export` writes the
lines and you paste them into your startup file:

```sh
monkeys export TYPESAFE_API_KEY
```

> ```
> export TYPESAFE_API_KEY="$(security find-generic-password -s monkeys -a TYPESAFE_API_KEY -w)"
> ```

No value is in that line. It asks the keychain when the shell starts, the way
you would have written it by hand, and on Linux it asks `secret-tool` instead.
With no names, inside a project, it writes one line per name the file lists.

`monkeys` writes nothing into your startup file for you: a value that every
process on the machine inherits is a decision to make with the file open.

The keychain treats `security` as its own program, so the first shell that
runs the line asks once whether to allow it. Answer Always Allow and it stays
quiet.

## pack

```sh
monkeys pack [@profile] [name] [--only ...]
```

Writes a project's values as one encrypted file, the only way they leave the
keyring. With no arguments it takes every profile the `.monkeys` file
declares:

```sh
monkeys pack
```

> ```
> Passphrase:
> Again:
> wrote test.foo.monkeys: @test.foo,foo @foo, 5 values
> ```

The file takes the first profile's name unless a word after `pack` names it.
It carries each profile's name, the names the project lists for it, and their
values, sealed with ChaCha20-Poly1305 under a key scrypt derives from the
passphrase. The file is safe to send over whatever you already use; the
passphrase goes another way.

A pack with a value still missing refuses, since a bundle that fills half a
profile is a bug for whoever receives it.

### --only

`--only` says which profiles and names, and reads the way the file is
written: a `@profile` opens a block, `@a,b` opens one for several profiles at
once, and the names after it belong to every profile in that block. A block
with no names after it goes whole; names before any `@` come from the default
profile, the first the file mentions. That is how a teammate gets test and
never production, or one key on its own:

```sh
monkeys pack --only @test.foo
monkeys pack shared --only @test.foo @foo
monkeys pack --only DATABASE_URL
monkeys pack --only @test.foo,foo DATABASE_URL
monkeys pack --only @test.foo DATABASE_URL @foo SENTRY_DSN
```

> ```
> wrote test.foo.monkeys: @test.foo, 2 values
> wrote shared.monkeys: @test.foo @foo, 5 values
> wrote test.foo.monkeys: @test.foo, 1 value
> wrote test.foo.monkeys: @test.foo,foo, 2 values
> wrote test.foo.monkeys: @test.foo @foo, 2 values
> ```

The bundle keeps that shape, block for block, and `unpack` writes it back as
the project file. A leading `@profile` before `--only` means that one profile,
with the names that follow. The file name goes before `--only`, which takes
the rest of the line. A name a profile does not list is refused rather than
left out.

The passphrase is read from standard input when it is not a terminal, for the
rare script that needs to.

## unpack

```sh
monkeys unpack <name> [directory]
```

Reads a bundle, stores its values in your keyring under each profile, and
writes the profiles and names as a `.monkeys` file:

```sh
monkeys unpack test.foo
```

> ```
> Passphrase:
> wrote .monkeys: @test.foo,foo @foo, 3 names
> stored test.foo/DATABASE_URL, foo/DATABASE_URL, test.foo/STRIPE_SECRET_KEY, foo/STRIPE_SECRET_KEY
> stored foo/SENTRY_DSN
> ```

`<name>` is the bundle, with or without its `.monkeys` suffix; a path works
too.

The file goes at the root of the git checkout, the way `.gitignore` sits at
the root, so `monkeys run` works from any directory in it. Outside a checkout
it goes in the current directory, and a second argument names the directory
outright. When a `.monkeys` file is already there, `unpack` adds a block at
the end for the names the file does not yet list, grouped the way the bundle
groups them, and leaves the rest of the file alone.

The passphrase is read from standard input when it is not a terminal.

## fill

```sh
monkeys fill @profile --with @profile
```

Gives the first profile the names it lacks, taking the values from the
second. Two profiles of one project usually share most of their values, and
the second is filled from the first:

```sh
monkeys fill @foo --with @test.foo
```

> ```
> filled @foo from @test.foo: STRIPE_SECRET_KEY
> kept 1 @foo already had
> still missing in @foo: SENTRY_DSN
> ```

`fill` moves only the names the target lacks and never touches a value it
already holds, so it is safe to run twice. It names every value it moved,
since a production profile filled from test is a decision to see written
down, and it exits non-zero while anything is still missing. No value is
printed.

Inside a project the names are the ones the file lists for the target;
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

A project's values travel as one encrypted file: `pack` on one machine,
`unpack` on the other. The file is safe to send over whatever you already
use; the passphrase goes another way.

On the machine that has the values, inside the checkout:

```sh
monkeys pack --only @test.foo
```

> ```
> Passphrase:
> Again:
> wrote test.foo.monkeys: @test.foo, 2 values
> ```

Send `test.foo.monkeys`. On the other machine, anywhere inside their
checkout:

```sh
monkeys unpack ~/Downloads/test.foo.monkeys
```

> ```
> Passphrase:
> wrote .monkeys: @test.foo, 2 names
> stored test.foo/DATABASE_URL, test.foo/STRIPE_SECRET_KEY
> ```

Their keyring now holds the values under the same profile, and `monkeys run
./hello.sh` works for them the way it works for you. When they cloned the
repository, the `.monkeys` file was already there, and `unpack` leaves it as
it was, adding only names it does not list.

A bundle has no place in a repository, and the ignore rule needs two lines,
because `*.monkeys` alone also matches the `.monkeys` file you do commit:

```
*.monkeys
!.monkeys
```

# Caveats

### What redaction can and cannot do

An agent that sets out to see a value can see it. `run` hands the value to a
process, and a process can do what it likes with what it holds: encode it,
split it, write it somewhere and read it back. Redaction catches the value
written out as it is, which is what a reflex produces, and nothing here claims
more than that.

That is enough, because the reflex is the whole problem. An agent does not
read `.env` out of curiosity. It reads it because a variable was empty, the
task was stuck, and `cat .env` was the shortest path back to the task. Take the
shortest path away and give it a shorter one, and the urge goes with it: `run`
puts the value where the task needs it, a missing name comes back as a message
that says what to ask for, `preview` and `doctor --short` answer "is it there"
without reading anything. The agent gets on with the task. What remains after
that is intent, and intent is a question for whoever runs the agent.

The same holds for people. A secret shared with a teammate stops being a paste
into a chat and becomes `pack` and `unpack`, sealed in transit and landing in
that person's keyring. And the bookkeeping a project keeps about its secrets, a
`.env` nobody commits, a `.env.example` that drifts from it, a `.gitignore` line
to keep the two apart, collapses into one committed `.monkeys` file that says
what is needed and holds nothing.

### The keychain prompt on macOS

A binary built from source carries an ad-hoc signature, whose identity is a
hash of the binary itself. A rebuild changes that identity, so the keychain
may ask you to allow access once when the new build first reads an item the
old one stored. The release builds are what `brew` and the install script
give you.

### The Secret Service on Linux

The Secret Service is a desktop session service. Over SSH or in a container
there is usually no session bus and no keyring daemon, and `monkeys` fails
saying so. Machines like that want a different mechanism, not this one.
