---
name: monkeys
description: Give a command an API key, token or password held in the OS keyring, without the value entering the conversation. Use when a command needs a credential, when one fails for a missing or empty credential, when asked where a key is kept, or when asked to store one.
---

# monkeys

`monkeys` keeps secrets in the macOS keychain or the Linux Secret Service and
spends them on one command at a time. Nothing it offers prints a stored value,
so the only thing to get right is how you spend one.

If `monkeys` is not on `PATH`, say so and point at
<https://github.com/eastriverlee/monkeys>. Do not work around it by asking for
the secret yourself.

## Spend a value

Name what the command reads, then the command:

```sh
monkeys run OPENROUTER_API_KEY ./hello.sh
monkeys run OPENROUTER_API_KEY,GITHUB_TOKEN ./deploy
```

Nothing in that line holds the secret, so nothing you write can spill it. The
exit status and the signals are the command's own. Its output comes back
through `monkeys`, and a stored value in it comes back as `[redacted NAME]`, so
`echo $NAME` tells you which value was there and never the value. Never add
`--no-redact`; it is for a person writing a value into a file on purpose. Reach
for `monkeys run --all <command>` only when you cannot tell which names the
command reads.

A project with a `.monkeys` file has already named what it needs:

```
@test.foo,foo
DATABASE_URL
STRIPE_SECRET_KEY
```

In that directory or below it, `run` takes only the command, and every name is
scoped to that profile, so `monkeys set STRIPE_SECRET_KEY` there stores into
the same profile the command reads from:

```sh
monkeys run ./hello.sh
monkeys run @foo ./deploy    # another profile the file declares
```

A `@` line may name several profiles, and a file may hold several blocks; a
profile's names are those of every block listing it, the first profile in the
file is the default, and `run @name` takes only a profile the file declares,
or a prefix that fits just one of them.
`monkeys doctor --short` prints one `missing @profile: A,B` line per profile
with a gap, nothing when there is none, and exits non-zero while any remains.

Read the file before adding a name; it is the list. A profile never falls back
to the personal one: a name missing in `@foo` is missing there even when a
bare copy exists.

A shared `<name>.monkeys` bundle fills a profile with `monkeys unpack`, which
writes `.monkeys` at the git root and
asks for a passphrase. Tell the person to run it; do not run it yourself.

The command you start is what expands the variable, since that is where it
exists. `$NAME` written into the `monkeys run` line is expanded by the shell
you are already in, which does not have the value:

```sh
monkeys run OPENROUTER_API_KEY curl -H "Authorization: Bearer $OPENROUTER_API_KEY" ...
# sends an empty Bearer

monkeys run OPENROUTER_API_KEY sh -c 'curl -H "Authorization: Bearer $OPENROUTER_API_KEY" ...'
# the single quotes reach the child intact
```

## When a value is missing

`run` stops before anything happens and names what to ask for:

```
monkeys: ANTHROPIC_API_KEY is not stored yet in @test.foo
nothing ran. ask the person to store it, then try again:
  monkeys set @test.foo ANTHROPIC_API_KEY
```

Pass that on. Storing is the person's move: typing a secret for them puts it in
the conversation before it reaches the keyring.

## Check without reading

`monkeys list` gives the names. `monkeys preview` gives each one masked, with
its length, which is enough to tell a key pasted whole from one that lost a
character.

## Never

- `echo "$SOME_KEY"`, `env`, `printenv`
- writing a value into a file, a log, a commit, or a bug report

Where a config file wants the secret, write whatever reference its format
offers, such as `${OPENROUTER_API_KEY}`, and let the program expand it.

`monkeys help` carries the full contract.
