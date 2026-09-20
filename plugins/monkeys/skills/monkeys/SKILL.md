---
name: monkeys
description: Give a command an API key, token or password held in the OS vault, without the secret entering the conversation. Use when a command needs a credential, when one fails for a missing or empty credential, when a project needs a new environment variable, when asked where a secret is kept, or when asked to store one.
---

# monkeys

`monkeys` keeps secrets in the macOS keychain or the Linux Secret Service and
spends them on one command at a time, by key: `KEY=secret`, where the key is
the environment variable's name. Nothing it offers prints a stored secret, so
the only thing to get right is how you spend one.

If `monkeys` is not on `PATH`, say so and point at
<https://github.com/eastriverlee/monkeys>. Do not work around it by asking for
the secret yourself.

## Spend a secret

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

In that directory or below it within the git checkout, `run` takes only the
command, and every key is scoped to the file's first profile:

```sh
monkeys run ./hello.sh
monkeys run @production ./deploy    # another profile the file declares
```

The `+` line is the namespace, so `@test` here is the profile `foo.test`, and
from outside the project it is `@foo.test`. A `@` line may name several
profiles and a file may hold several blocks; a profile's keys are those of
every block listing it. A `KEY=value` line is a value that is not secret, and
`run` puts those in the environment too.

A profile never falls back to the keys with no profile: a key missing in
`@production` is missing there even when a copy with no profile exists.
Inside a project a bare `@` reaches the keys with no profile, with the key
given again: `monkeys run @ TYPESAFE_API_KEY claude`.

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
