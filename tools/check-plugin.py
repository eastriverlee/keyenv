#!/usr/bin/env python3
"""Hold plugin.json to Agent Plugins 1.0.0, and the Claude Code manifest to it.

1.0.0 and 1.1.0 permit the same manifest fields, and Codex accepts 1.0.0 alone
(verified by installing: 1.1.0 is refused as an invalid plugin.json).

The portable manifest is closed: only the fields the specification names may
appear, and the name has a fixed grammar. Claude Code reads its own copy at
.claude-plugin/plugin.json, so the fields both carry are compared here and a
drift fails the check.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"
PERMITTED = {"$schema", "name", "version", "description", "author", "homepage", "repository", "license", "keywords", "extensions"}
NAME = re.compile(r"^(?!.*(--|\.\.))[a-z0-9](?:[a-z0-9.-]{0,62}[a-z0-9])?$")
SHARED = ("name", "version", "description", "license")


def failures():
    portable = json.loads((ROOT / "plugin.json").read_text())
    claude = json.loads((ROOT / ".claude-plugin" / "plugin.json").read_text())
    if portable.get("$schema") != SCHEMA:
        yield f"plugin.json: $schema must be {SCHEMA}"
    for field in sorted(set(portable) - PERMITTED):
        yield f"plugin.json: {field} is not a permitted field"
    if not NAME.match(portable.get("name", "")):
        yield f"plugin.json: name {portable.get('name')!r} breaks the name constraints"
    author = portable.get("author", {})
    for field in sorted(set(author) - {"name", "email", "url"}):
        yield f"plugin.json: author.{field} is not permitted"
    for field in SHARED:
        if portable.get(field) != claude.get(field):
            yield f"{field} differs: plugin.json has {portable.get(field)!r}, .claude-plugin/plugin.json has {claude.get(field)!r}"
    if not (ROOT / "skills" / "monkeys" / "SKILL.md").is_file():
        yield "skills/monkeys/SKILL.md is missing"


problems = list(failures())
for problem in problems:
    print(problem, file=sys.stderr)
sys.exit(1 if problems else 0)
