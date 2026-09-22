#!/usr/bin/env python3
"""Write the body of a release from the commits a tag carries.

A release whose notes are worth writing by hand gets a file in
.github/release-notes named after its tag, committed before the tag is pushed,
and that file becomes the body whole; TEMPLATE.md beside it is the shape those
take. Every other release is grouped out of the conventional commit subjects
between this tag and the one before it, which is what the repository has
instead of pull requests to categorise.

Either way the install lines and the changelog link are appended here, so every
release ends the same way.

    python3 tools/release-notes.py v1.4.1 > notes.md
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HANDWRITTEN = ROOT / ".github" / "release-notes"
REPOSITORY = "https://github.com/eastriverlee/monkeys"
SUBJECT = re.compile(r"^(?P<type>[a-z]+)(?:\((?P<scope>[^)]+)\))?(?P<breaking>!)?: (?P<summary>.+)$")
SECTIONS = [
    ("Breaking", {"breaking"}),
    ("Added", {"feat"}),
    ("Fixed", {"fix"}),
    ("Changed", {"refactor", "perf"}),
    ("Documentation", {"docs"}),
]


def previous_tag(tag):
    finding = subprocess.run(
        ["git", "describe", "--tags", "--abbrev=0", f"{tag}^"],
        capture_output=True, text=True, cwd=ROOT,
    )
    return finding.stdout.strip() if finding.returncode == 0 else ""


def subjects(tag, previous):
    span = f"{previous}..{tag}" if previous else tag
    log = subprocess.run(
        ["git", "log", "--no-merges", "--reverse", "--format=%s", span],
        capture_output=True, text=True, check=True, cwd=ROOT,
    )
    return log.stdout.splitlines()


def entry(subject):
    match = SUBJECT.match(subject)
    if not match:
        return None
    kind = "breaking" if match["breaking"] else match["type"]
    summary = match["summary"]
    return kind, f"`{match['scope']}`: {summary}" if match["scope"] else summary


def generated_body(tag, previous):
    entries = [found for found in map(entry, subjects(tag, previous)) if found]
    written = []
    for heading, kinds in SECTIONS:
        lines = [f"- {summary}" for kind, summary in entries if kind in kinds]
        if lines:
            written.append(f"### {heading}\n\n" + "\n".join(lines))
    return "\n\n".join(written)


def body(tag, previous):
    handwritten = HANDWRITTEN / f"{tag}.md"
    if handwritten.is_file():
        return handwritten.read_text().strip()
    return generated_body(tag, previous)


def install():
    return (
        "### Install\n\n"
        "```sh\n"
        "curl -fsSL https://monk3ys.dev/install | sh    # macOS and Linux\n"
        "brew install eastriverlee/tap/monkeys          # or Homebrew\n"
        "```\n\n"
        "The macOS build is a universal binary, and the Linux builds carry the "
        "Swift runtime, so they need only libc and libstdc++ and `secret-tool` "
        "to reach the vault. `checksums.txt` covers every archive below."
    )


def changelog(tag, previous):
    if not previous:
        return f"**Full Changelog**: {REPOSITORY}/commits/{tag}"
    return f"**Full Changelog**: {REPOSITORY}/compare/{previous}...{tag}"


tag = sys.argv[1]
previous = previous_tag(tag)
print("\n\n".join(part for part in [body(tag, previous), install(), changelog(tag, previous)] if part))
