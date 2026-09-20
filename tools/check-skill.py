#!/usr/bin/env python3
"""Fail when the skill or the site names a command the binary does not have.

Both restate a few invocations: the skill because an agent reads it before
running anything, the site because a visitor does. This keeps those copies
honest: every `monkeys <verb>` written as an invocation must be a verb `monkeys help`
lists.
"""

import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
COPIES = [
    ROOT / "plugins" / "monkeys" / "skills" / "monkeys" / "SKILL.md",
    ROOT / "site" / "src" / "routes" / "+page.svelte",
    ROOT / "README.md",
    ROOT / "DOCS.md",
]
MENTION = re.compile(r"(?:^[ \t]*|\$ |[`(;|&] ?)monkeys (\w[\w-]*)", re.M)
CODE_IN_MARKUP = re.compile(r"<code[^>]*>.*?</code>", re.S)
SCRIPT_BLOCK = re.compile(r"<script[^>]*>(.*?)</script>", re.S)
STRING_LITERAL = re.compile(r"'[^']*'|`[^`]*`|\"[^\"]*\"", re.S)
INVOCATION_LINE = re.compile(r"^\s*(?:\$ )?monkeys ")
CODE_IN_MARKDOWN = re.compile(r"```.*?```|`[^`]*`", re.S)


def code_spans(path):
    """The parts of a page or a skill that are written as code, joined."""
    text = path.read_text()
    if path.suffix == ".md":
        return "\n".join(match.group(0) for match in CODE_IN_MARKDOWN.finditer(text))
    spans = [match.group(0) for match in CODE_IN_MARKUP.finditer(text)]
    for script in SCRIPT_BLOCK.finditer(text):
        for literal in STRING_LITERAL.finditer(script.group(1)):
            spans.extend(line for line in literal.group(0).strip("'`\"").splitlines() if INVOCATION_LINE.match(line))
    return "\n".join(spans)


def listed_verbs(binary):
    help_text = subprocess.run([binary], capture_output=True, text=True).stdout
    return {match.group(1) for match in MENTION.finditer(help_text)}


def main():
    binary = sys.argv[1] if len(sys.argv) > 1 else "monkeys"
    known = listed_verbs(binary) | {"help"}
    if not known:
        sys.exit(f"{binary} printed no commands")

    for copy in COPIES:
        unknown = sorted(set(MENTION.findall(code_spans(copy))) - known)
        if unknown:
            sys.exit(f"{copy.relative_to(ROOT)} names commands monkeys does not have: " + ", ".join(unknown))
        print(f"{copy.relative_to(ROOT)} agrees with {binary}")


if __name__ == "__main__":
    main()
