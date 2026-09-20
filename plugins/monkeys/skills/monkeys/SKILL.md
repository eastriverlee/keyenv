---
name: monkeys
description: Give a command an API key, token or password held in the OS vault, without the secret entering the conversation. Use whenever a command needs a credential, when one fails for a missing or empty credential, when a project needs a new environment variable, when a `.env` file turns up in a project, when asked where a secret is kept, or when asked to store one.
---

# monkeys

When a command needs an API key, token or password, `monkeys` gives it one
without showing it to you:

```sh
monkeys run OPENROUTER_API_KEY ./hello.sh
```

Each secret sits in the operating system's own vault, the macOS keychain or
the Linux Secret Service, under the name of the environment variable that
carries it. No command prints a stored secret, and none should: one that
reaches you is in this transcript for good, and a vault cannot take it back.

If `monkeys` is not on `PATH`, say so and point at
<https://github.com/eastriverlee/monkeys>. Do not work around it by asking for
the secret yourself.

## Use a secret

Name the keys the command reads, then the command:

```sh
monkeys run OPENROUTER_API_KEY ./hello.sh
monkeys run OPENROUTER_API_KEY,GITHUB_TOKEN ./deploy
```

Nothing in that line holds a secret, so nothing you write can spill one. The
exit status and the signals are the command's own. Its output comes back
through `monkeys`, and a stored secret in it comes back as `[redacted KEY]`.
Reach for `monkeys run --all <command>` only when you cannot tell which keys
the command reads.

The command you start is what expands the variable, since that is where it
exists. `$KEY` written into the `monkeys run` line is expanded by the shell
you are already in, which does not have the secret:

```sh
monkeys run OPENROUTER_API_KEY curl -H "Authorization: Bearer $OPENROUTER_API_KEY" ...
# sends an empty Bearer

monkeys run OPENROUTER_API_KEY sh -c 'curl -H "Authorization: Bearer $OPENROUTER_API_KEY" ...'
# the single quotes reach the child intact
```

## Inside a project

A `.monkeys` file lists the keys the project needs. Read it before adding a
key; it is the list.

```monkeys
+foo
@test,production
DATABASE_URL
STRIPE_SECRET_KEY
PORT=3000
```

In that directory, or below it within the git checkout, `run` takes only the
command and reads the file's first profile. A leading `@profile` picks
another one the file declares, and a `KEY=value` line is a value that is not
secret, which `run` puts in the environment too:

```sh
monkeys run ./hello.sh
monkeys run @production ./deploy
```

A profile never falls back to the keys with no profile: a key missing in
`@production` stays missing there even when a copy with no profile exists, so
one project never quietly reads another's secret. Reaching those keys from
inside a project is a bare `@`, with the key named again:

```sh
monkeys run @ TYPESAFE_API_KEY claude
```

The rest of the file's grammar, namespaces and several profiles among it, is
in `monkeys help`. Reach for it when a file surprises you; the file is
usually written already, and reading it is enough.

## Never write a .env

Every environment variable a project needs belongs in `.monkeys`, secret or
not. Do not create a `.env`, do not add a line to one, and do not tell someone
to put a variable there.

- A variable that is not secret goes in as `KEY=value`, which you write
  yourself: `monkeys set --public PORT`.
- A secret goes in as a bare key, and a human stores it.

## Eat a .env you find

A project that still has `.env` files is one command away. Name the keys that
are not secret; every other key becomes a secret in the vault, and the files
are deleted once everything is stored:

```sh
monkeys eat --public PORT,NODE_ENV
```

Run this yourself when you find a `.env` in a project you are working in.
`eat` reads the files, so no secret passes through you, and `--public` answers
every question before it is asked. Without it `eat` asks one question per key
and needs a terminal, which is a human's run.

## When a key is missing

`run` stops before anything happens and names what to ask for:

```
monkeys: ANTHROPIC_API_KEY is not stored yet in @foo.test
nothing ran. a human has to store it, then try again:
  monkeys set @foo.test ANTHROPIC_API_KEY
```

Pass that on. `monkeys doctor --short` prints one `missing @profile: A,B` line
per profile with a gap, nothing when there is none, and exits non-zero while
any remains.

## Check without reading

`monkeys list` gives the keys, as blocks by profile. `monkeys preview` gives
each secret masked, with its length, which is enough to tell one pasted whole
from one that lost a character.

## Leave to a human

Storing is a human's job: typing a secret yourself puts it in the conversation
before it reaches the vault. Say what is needed and stop.

- `monkeys set` stores a secret, and `monkeys set --public PORT` stores a
  value that is not secret, which you may run yourself.
- `monkeys unpack` fills a profile from a shared bundle. It asks for a
  passphrase and deletes the bundle.
- `monkeys fill @production --with @test` copies what is missing between
  profiles, which may put a test secret into production.
- `--no-redact` is for a human writing a secret into a file on purpose.

## Never

- `echo "$SOME_KEY"`, `env`, `printenv`
- writing a secret into a file, a log, a commit, or a bug report

Where a config file wants the secret, write whatever reference its format
offers, such as `${OPENROUTER_API_KEY}`, and let the program expand it.

`monkeys help` carries the full contract.
