#!/usr/bin/env python3
"""Render a terminal transcript of real monkeys output as an SVG, through freeze.

Every line in the picture is produced by running the command shown above it,
so the image cannot drift from what monkeys prints. The commands are the ones
the landing page walks through, the first of them prompting for a secret on a
pty the way a terminal does, with the word written to it rather than piped in,
so the command in the picture is the command a person types. The secret the
picture stores is forgotten in the last frame, and a name you already hold
stops the render rather than being replaced.

The window is drawn by freeze: brew install charmbracelet/tap/freeze.
"""

import os
import pty
import re
import select
import shutil
import subprocess
import sys
import tempfile
import time

BACKGROUND = "#17181c"
PROMPT = "\x1b[38;5;202m$\x1b[0m "
# The site's code blocks are Shiki's github-dark: words of a command in one
# blue, flags in another, output in grey. The same three colours here.
WORD = "\x1b[38;2;165;214;255m"
FLAG = "\x1b[38;2;121;192;255m"
OUTPUT = "\x1b[38;2;139;148;158m"
RESET = "\x1b[0m"
FONT_FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "site", "static", "fonts", "CascadiaCode.woff2"
)

CONTROL = re.compile(r"[\x00-\x08\x0b-\x1a\x1c-\x1f\x7f]")

OPEN = """test "$SUPER_SECRET" = sesame && echo opened || echo closed"""
# Each command, and what a person types when it asks for a secret.
COMMANDS = [
    ("monkeys remember SUPER_SECRET", "sesame"),
    (
        f"""monkeys run SUPER_SECRET sh -c '
  {OPEN}
  echo "the word was $SUPER_SECRET"
'""",
        None,
    ),
    ("monkeys forget SUPER_SECRET", None),
    (
        f"""monkeys run SUPER_SECRET sh -c '
  {OPEN}
'""",
        None,
    ),
]
# The picture stores this itself, in its first frame, and forgets it in its
# last. The word never reaches the image: the prompt does not echo it, and the
# run that uses it prints it back redacted, which is the point of the frame.
DEMO_NAMES = ["SUPER_SECRET"]


def stored_names():
    """The keys with no profile, read from the first block that list prints."""
    listing = subprocess.run(["monkeys", "list"], capture_output=True, text=True).stdout
    names, in_first_block = set(), False
    for line in listing.splitlines():
        if line.startswith("@"):
            in_first_block = line == "@"
        elif in_first_block and line:
            names.add(line)
    return names


def borrowed():
    """Refuse a name you already hold, since the picture stores over it."""
    collisions = sorted(set(DEMO_NAMES) & stored_names())
    if collisions:
        sys.exit(
            "already stored: " + ", ".join(collisions) + "\n"
            "the picture stores these itself and forgets them afterwards, which "
            "would take yours with them. Rename yours, or rename them in DEMO_NAMES."
        )
    return DEMO_NAMES


def cleaned(names):
    for name in names:
        subprocess.run(["monkeys", "forget", name], capture_output=True)


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


def typed(command, answer, directory):
    """Answer a command that prompts, on a pty, the way a person at one does.

    The answer waits for the prompt. getpass turns echo off with TCSAFLUSH,
    which throws away input that arrived before it, so a word written ahead of
    the prompt is a word the command never sees.
    """
    child, terminal = pty.fork()
    if child == 0:
        try:
            os.chdir(directory)
            os.environ["CLICOLOR_FORCE"] = "1"
            os.execvp("sh", ["sh", "-c", command])
        finally:
            os._exit(1)
    spoken, answered, deadline = b"", False, time.monotonic() + 10
    while time.monotonic() < deadline:
        if not select.select([terminal], [], [], 0.2)[0]:
            continue
        try:
            heard = os.read(terminal, 1024)
        except OSError:
            break
        if not heard:
            break
        spoken += heard
        if not answered and spoken.rstrip().endswith(b":"):
            os.write(terminal, (answer + "\n").encode())
            answered = True
    os.close(terminal)
    os.waitpid(child, 0)
    if not answered:
        sys.exit(f"no prompt came from: {command}")
    return CONTROL.sub("", spoken.decode()).rstrip("\n")


def coloured_command(command):
    words = [(FLAG if word.startswith("-") else WORD) + word + RESET for word in command.split(" ")]
    return " ".join(words)


def greyed_output(text):
    """Grey as the default, with every colour monkeys chose left in place."""
    return OUTPUT + text.replace(RESET, RESET + OUTPUT).replace("\n", "\n" + OUTPUT)


def transcript(directory):
    blocks = []
    for command, answer in COMMANDS:
        spoken = typed(command, answer, directory) if answer else captured(command, directory)
        blocks.append(PROMPT + coloured_command(command) + "\n" + greyed_output(spoken))
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
            stdin=subprocess.DEVNULL,
        )
    finally:
        os.unlink(source)


if __name__ == "__main__":
    if shutil.which("freeze") is None:
        sys.exit("freeze is not installed: brew install charmbracelet/tap/freeze")
    destination = sys.argv[1] if len(sys.argv) > 1 else "terminal.svg"
    names = borrowed()
    with tempfile.TemporaryDirectory() as directory:
        try:
            frozen(transcript(directory), destination)
        finally:
            cleaned(names)
    print(f"wrote {destination}")
