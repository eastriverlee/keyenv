<!-- The title is a claim about the code, in the commit style: `feat: fill copies only what the target lacks`. -->

## What changes

<!-- One paragraph. What a user or an agent sees that they did not see before. -->

## Why

<!-- The problem this solves, or the issue it closes. Say what you deliberately did not do. -->

## How it was verified

<!-- `make check` is the floor. Add what you ran by hand: the commands, on which platform, and what they printed. Output with a secret in it is replaced with `[redacted]`. -->

- [ ] `make check` passes
- [ ] Any changed command was run on macOS or Linux and its output matches what the docs now say

## If a command changed

- [ ] `monkeys help` still fits in 78 columns
- [ ] `DOCS.md` shows the new form and its actual output
- [ ] `README.md`, `SKILL.md` and the landing page say the same thing where they mention it
- [ ] The version is bumped in `plugins/monkeys/plugin.json`, its `.claude-plugin/plugin.json`, and the two marketplace files under `.claude-plugin/` and `.agents/plugins/`
