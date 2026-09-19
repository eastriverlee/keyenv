#!/usr/bin/env python3
"""Fail when the skill names a command the binary does not have.

The skill has to restate a few invocations, because an agent reads it before
running anything. This keeps that copy honest: every `monkeys <verb>` written
in SKILL.md must be a verb `monkeys help` lists.
"""

import pathlib
import re
import subprocess
import sys

SKILL = pathlib.Path(__file__).resolve().parent.parent / "skills" / "monkeys" / "SKILL.md"
MENTION = re.compile(r"\bmonkeys ([a-z][a-z-]*)")


def listed_verbs(binary):
    help_text = subprocess.run([binary], capture_output=True, text=True).stdout
    return {match.group(1) for match in MENTION.finditer(help_text)}


def main():
    binary = sys.argv[1] if len(sys.argv) > 1 else "monkeys"
    known = listed_verbs(binary) | {"help"}
    if not known:
        sys.exit(f"{binary} printed no commands")

    unknown = sorted(
        {verb for verb in MENTION.findall(SKILL.read_text())} - known
    )
    if unknown:
        sys.exit("SKILL.md names commands monkeys does not have: " + ", ".join(unknown))
    print(f"SKILL.md agrees with {binary}")


if __name__ == "__main__":
    main()
