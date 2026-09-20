#!/usr/bin/env python3
"""Read every .monkeys example in the docs with the binary itself.

The file format is shown in four places, and a copy only stays right while
nothing changes. Each example is written to a directory and read back, so one
the tool would reject cannot sit in the docs.
"""

import pathlib
import re
import subprocess
import sys
import tempfile

given = sys.argv[1] if len(sys.argv) > 1 else "monkeys"
BINARY = str(pathlib.Path(given).resolve()) if "/" in given else given
repository = pathlib.Path(__file__).resolve().parent.parent
FENCE = re.compile(r"^```monkeys[^\n]*\n(.*?)^```", re.MULTILINE | re.DOTALL)
LANDING_FILE = re.compile(r"const \w*[Ff]ile = `([^`]*)`")

sources = [
    repository / "README.md",
    repository / "DOCS.md",
    repository / "plugins/monkeys/skills/monkeys/SKILL.md",
    repository / "site/src/routes/+page.svelte",
]


def examples(source: pathlib.Path):
    text = source.read_text()
    blocks = FENCE.findall(text)
    if source.suffix == ".svelte":
        blocks += LANDING_FILE.findall(text)
    for block in blocks:
        body = block.replace("\\n", "\n").strip("\n")
        if body.strip():
            yield body


failures = []
checked = 0
for source in sources:
    for body in examples(source):
        checked += 1
        with tempfile.TemporaryDirectory() as directory:
            pathlib.Path(directory, ".monkeys").write_text(body + "\n")
            finished = subprocess.run(
                [BINARY, "doctor"], cwd=directory, capture_output=True, text=True
            )
        message = finished.stderr.strip()
        if message.startswith("monkeys:") and "not stored yet" not in message:
            name = source.relative_to(repository)
            failures.append(f"{name}: {message.replace(directory, '.')}\n{body}\n")

for failure in failures:
    print(failure, file=sys.stderr)
print(f"read {checked} .monkeys examples" if not failures else f"{len(failures)} rejected")
sys.exit(1 if failures else 0)
