#!/usr/bin/env python3
"""Render a terminal transcript of real monkeys output as an SVG, through freeze.

Every line in the picture is produced by running the command shown above it,
so the image cannot drift from what monkeys prints. The one exception is the
answer the demo script gives back, which replays a real OpenRouter reply rather
than calling out, so anyone can render this without a key. The demo names are
stored first and removed afterwards, and a name you already hold is left
alone.

The window is drawn by freeze: brew install charmbracelet/tap/freeze.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

BACKGROUND = "#17181c"
PROMPT = "\x1b[38;5;202m$\x1b[0m "
FONT_FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "site", "static", "fonts", "CascadiaCode.woff2"
)

CONTROL = re.compile(r"[\x00-\x08\x0b-\x1a\x1c-\x1f\x7f]")

COMMANDS = [
    "monkeys run OPENROUTER_API_KEY,ANTHROPIC_API_KEY ./hello",
    "monkeys run OPENROUTER_API_KEY ./hello",
    "monkeys preview GITHUB_TOKEN STRIPE_SECRET_KEY",
]
HELLO = """#!/bin/sh
# Stands in for the README's curl to OpenRouter, replaying the answer that call
# returned when it was run for real, so rendering needs no key and no network.
# Change it when the README's script stops answering this.
echo "Hello world!"
"""
# Shaped only for the picture: two leading characters, one trailing, a length.
# Deliberately unlike any provider's real key, so a secret scanner has nothing
# to recognise.
SHOWN_VALUES = {
    "GITHUB_TOKEN": "gh-demo-" + "x" * 31 + "f",
    "STRIPE_SECRET_KEY": "sk-demo-" + "x" * 20 + "2",
}
# run prints neither the value nor its shape, so whatever is stored here is
# safe to spend in the picture.
SPENT_VALUES = {
    "OPENROUTER_API_KEY": "sk-demo-" + "x" * 64 + "2",
}
DEMO_VALUES = {**SHOWN_VALUES, **SPENT_VALUES}


def stored_names():
    listing = subprocess.run(["monkeys", "list"], capture_output=True, text=True)
    return set(listing.stdout.split())


def seeded():
    """Store the demo values that are missing, and report which to clean up."""
    held = stored_names()
    collisions = sorted(SHOWN_VALUES.keys() & held)
    if collisions:
        sys.exit(
            "already stored: " + ", ".join(collisions) + "\n"
            "preview would put a real value's shape into the picture. "
            "Remove those names, or rename them in SHOWN_VALUES."
        )
    added = []
    for name, value in DEMO_VALUES.items():
        if name in held:
            continue
        subprocess.run(["monkeys", "set", name], input=value, text=True, capture_output=True)
        added.append(name)
    return added


def cleaned(names):
    for name in names:
        subprocess.run(["monkeys", "remove", name], capture_output=True)


def captured(command, directory):
    """Run one command with colour forced on, and keep stderr in its place."""
    finished = subprocess.run(
        ["sh", "-c", command],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        cwd=directory,
        env={**os.environ, "CLICOLOR_FORCE": "1"},
    )
    return CONTROL.sub("", finished.stdout).rstrip("\n")


def transcript(directory):
    blocks = [PROMPT + command + "\n" + captured(command, directory) for command in COMMANDS]
    return "\n\n".join(blocks) + "\n"


def frozen(text, destination):
    with tempfile.NamedTemporaryFile("w", suffix=".ansi", delete=False) as handle:
        handle.write(text)
        source = handle.name
    try:
        subprocess.run(
            [
                "freeze",
                "--execute", f"cat {source}",
                "--window",
                "--background", BACKGROUND,
                "--padding", "20,28",
                "--border.radius", "10",
                "--shadow.blur", "0",
                "--font.file", FONT_FILE,
                "--font.family", "Cascadia Code",
                "--font.size", "14",
                "--output", destination,
            ],
            check=True,
            capture_output=True,
        )
    finally:
        os.unlink(source)


if __name__ == "__main__":
    if shutil.which("freeze") is None:
        sys.exit("freeze is not installed: brew install charmbracelet/tap/freeze")
    destination = sys.argv[1] if len(sys.argv) > 1 else "terminal.svg"
    borrowed = seeded()
    with tempfile.TemporaryDirectory() as directory:
        helper = os.path.join(directory, "hello")
        with open(helper, "w") as handle:
            handle.write(HELLO)
        os.chmod(helper, 0o755)
        try:
            frozen(transcript(directory), destination)
        finally:
            cleaned(borrowed)
    print(f"wrote {destination}")
