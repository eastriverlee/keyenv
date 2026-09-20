---
name: monkeys
description: Give a command an API key, token or password held in the OS vault, without the secret entering the conversation. Use when a command needs a credential, when one fails for a missing or empty credential, when asked where a secret is kept, or when asked to store one.
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
through `monkeys`, and a stored secret in it comes back as `[redacted KEY]`,
so `echo $KEY` tells you which secret was there and never the secret. Never
add `--no-redact`; it is for a human writing a secret into a file on purpose.
Reach for `monkeys run --all <command>` only when you cannot tell which keys
the command reads.

A project with a `.monkeys` file has already listed the keys it needs:

```
@test.foo,foo
DATABASE_URL
STRIPE_SECRET_KEY
```

In that directory or below it within the git checkout, `run` takes only the
command, and every key is scoped to that profile, so `monkeys set
STRIPE_SECRET_KEY` there stores into the same profile the command reads from:

```sh
monkeys run ./hello.sh
monkeys run @foo ./deploy    # another profile the file declares
```

A `@` line may name several profiles, and a file may hold several blocks; a
profile's keys are those of every block listing it, the first profile in the
file is the default, and `run @name` takes only a profile the file declares,
or a prefix that fits just one of them. `monkeys doctor --short` prints one
`missing @profile: A,B` line per profile with a gap, nothing when there is
none, and exits non-zero while any remains. When another profile of the same
project holds a missing key, `monkeys fill @foo --with @test.foo` fills the
gap without printing a secret; a human decides that, since it may put a test
secret into production.

Read the file before adding a key; it is the list. A profile never falls back
to the global keys: a key missing in `@foo` is missing there even when a
global copy exists. A key stored outside any project has no profile; inside a
project a bare `@` means no profile and reaches it, with the key given again:
`monkeys run @ TYPESAFE_API_KEY claude`.

A shared `<name>.monkeys` bundle fills a profile with `monkeys unpack`, which
writes `.monkeys` at the git root and asks for a passphrase. A human runs it;
do not run it yourself.

The command you start is what expands the variable, since that is where it
exists. `$KEY` written into the `monkeys run` line is expanded by the shell
you are already in, which does not have the secret:

```sh
monkeys run OPENROUTER_API_KEY curl -H "Authorization: Bearer $OPENROUTER_API_KEY" ...
# sends an empty Bearer

monkeys run OPENROUTER_API_KEY sh -c 'curl -H "Authorization: Bearer $OPENROUTER_API_KEY" ...'
# the single quotes reach the child intact
```

## When a secret is missing

`run` stops before anything happens and names what to ask for:

```
monkeys: ANTHROPIC_API_KEY is not stored yet in @test.foo
nothing ran. a human has to store it, then try again:
  monkeys set @test.foo ANTHROPIC_API_KEY
```

Pass that on. Storing is a human's job: typing a secret yourself puts it in the
conversation before it reaches the vault.

## Check without reading

`monkeys list` gives the keys. `monkeys preview` gives each secret masked,
with its length, which is enough to tell one pasted whole from one that lost a
character.

## Never

- `echo "$SOME_KEY"`, `env`, `printenv`
- writing a secret into a file, a log, a commit, or a bug report

Where a config file wants the secret, write whatever reference its format
offers, such as `${OPENROUTER_API_KEY}`, and let the program expand it.

`monkeys help` carries the full contract.
