#!/usr/bin/env python3
"""Fail when a release would go out unnamed, or with a body rendered ragged.

A release whose name is empty is shown as "<tag>: <subject of the commit it
tags>", so the publish command has to name it. And a release body is rendered
with hard line breaks, so a paragraph wrapped at 80 columns arrives with a
break inside every sentence: release-notes.py unwraps them on the way out, and
each set of notes is rendered here to see that it still does.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "release.yml"
SOURCES = sorted((ROOT / ".github" / "release-notes").glob("v*.md"))
PUBLISH = re.compile(r"^.*gh release create.*$", re.M)
OPENS_A_LINE = re.compile(r"^(?:```|>|#|-|\*|\||\d+\. )")


def publishing_failures():
    commands = PUBLISH.findall(WORKFLOW.read_text())
    if not commands:
        yield f"{WORKFLOW.name}: no gh release create command to check"
    for command in commands:
        if "--title" not in command:
            yield f"{WORKFLOW.name}: gh release create needs --title, or the release goes out unnamed"


def rendered(tag):
    finished = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "release-notes.py"), tag],
        capture_output=True, text=True, cwd=ROOT,
    )
    return finished.stdout if finished.returncode == 0 else None


def wrapped_line(body):
    fenced = False
    previous = ""
    for line in body.splitlines():
        stripped = line.strip()
        continues = previous and not previous.startswith(("```", ">"))
        if not fenced and continues and stripped and not OPENS_A_LINE.match(stripped):
            return stripped
        if stripped.startswith("```"):
            fenced = not fenced
        previous = stripped
    return ""


def notes_failures():
    for source in SOURCES:
        body = rendered(source.stem)
        if body is None:
            yield f"{source.name}: release-notes.py would not render it"
            continue
        wrapped = wrapped_line(body)
        if wrapped:
            yield f"{source.name}: a paragraph is still wrapped, and breaks at {wrapped!r}"


failures = list(publishing_failures()) + list(notes_failures())
for failure in failures:
    print(failure, file=sys.stderr)
print(f"read {len(SOURCES)} sets of release notes" if not failures else f"{len(failures)} rejected")
sys.exit(1 if failures else 0)
