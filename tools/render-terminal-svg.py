#!/usr/bin/env python3
"""Render a terminal transcript of real monkeys output as an SVG.

Every line in the picture is produced by running the command shown above it,
so the image cannot drift from what monkeys prints. The one exception is the
answer the demo script gives back, which replays a real OpenRouter reply rather
than calling out, so anyone can render this without a key. The demo names are
stored first and removed afterwards, and a name you already hold is left
alone.
"""

import os
import re
import subprocess
import sys
import tempfile

BACKGROUND = "#17181c"
WINDOW_BORDER = "#2b2d34"
FOREGROUND = "#d6d6d0"
PROMPT = "#6f7380"
DIM_OPACITY = "0.55"
COLORS = {
    "31": "#f1707b",
    "32": "#8bcf72",
    "36": "#59c2de",
    "38;5;202": "#e94100",
}

FONT_SIZE = 13.5
CHARACTER_WIDTH = FONT_SIZE * 0.6
LINE_HEIGHT = 21
TOP_PADDING = 52
SIDE_PADDING = 22
BOTTOM_PADDING = 18

SEQUENCE = re.compile(r"\x1b\[([0-9;]*)m")
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
    return CONTROL.sub("", finished.stdout)


def spans(line):
    """Split one line into (text, styles) pairs, styles being SGR parameters."""
    result = []
    active = []
    position = 0
    for match in SEQUENCE.finditer(line):
        if match.start() > position:
            result.append((line[position:match.start()], list(active)))
        parameters = match.group(1)
        if parameters in ("", "0"):
            active = []
        else:
            active.append(parameters)
        position = match.end()
    if position < len(line):
        result.append((line[position:], list(active)))
    return result


def escaped(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def tspan(text, styles, column):
    """One span, anchored at its own column so a bold run cannot shift the rest."""
    attributes = [f'x="{SIDE_PADDING + column * CHARACTER_WIDTH:.1f}"']
    for style in styles:
        if style == "1":
            attributes.append('font-weight="600"')
        elif style == "2":
            attributes.append(f'opacity="{DIM_OPACITY}"')
        elif style == "prompt":
            attributes.append(f'fill="{PROMPT}"')
        elif style in COLORS:
            attributes.append(f'fill="{COLORS[style]}"')
    return f'<tspan {" ".join(attributes)}>{escaped(text)}</tspan>'


def transcript(directory):
    lines = []
    for index, command in enumerate(COMMANDS):
        if index:
            lines.append(None)
        lines.append(("prompt", command))
        body = captured(command, directory).split("\n")
        while body and not body[-1].strip():
            body.pop()
        lines.extend(("output", line) for line in body)
    return lines


def rendered(lines):
    widest = max(
        len(SEQUENCE.sub("", text)) + (2 if kind == "prompt" else 0)
        for kind, text in (entry for entry in lines if entry)
    )
    width = round((widest + 2) * CHARACTER_WIDTH) + SIDE_PADDING * 2
    height = TOP_PADDING + len(lines) * LINE_HEIGHT + BOTTOM_PADDING

    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        f'width="{width}" height="{height}" font-family="ui-monospace, SFMono-Regular, '
        f'Menlo, Consolas, monospace" font-size="{FONT_SIZE}">',
        f'<rect width="{width}" height="{height}" rx="10" fill="{BACKGROUND}" '
        f'stroke="{WINDOW_BORDER}"/>',
    ]
    for offset, color in enumerate(("#ff5f57", "#febc2e", "#28c840")):
        out.append(f'<circle cx="{24 + offset * 19}" cy="24" r="6" fill="{color}"/>')

    for row, entry in enumerate(lines):
        if entry is None:
            continue
        kind, text = entry
        baseline = TOP_PADDING + row * LINE_HEIGHT
        out.append(
            f'<text x="{SIDE_PADDING}" y="{baseline}" fill="{FOREGROUND}" '
            f'xml:space="preserve">'
        )
        if kind == "prompt":
            out.append(tspan("$ ", ["prompt"], 0))
            out.append(tspan(text, [], 2))
        else:
            column = 0
            for part, styles in spans(text):
                out.append(tspan(part, styles, column))
                column += len(part)
        out.append("</text>")
    out.append("</svg>")
    return "\n".join(out)


if __name__ == "__main__":
    destination = sys.argv[1] if len(sys.argv) > 1 else "terminal.svg"
    borrowed = seeded()
    with tempfile.TemporaryDirectory() as directory:
        helper = os.path.join(directory, "hello")
        with open(helper, "w") as handle:
            handle.write(HELLO)
        os.chmod(helper, 0o755)
        try:
            picture = rendered(transcript(directory))
        finally:
            cleaned(borrowed)
    with open(destination, "w") as handle:
        handle.write(picture + "\n")
    print(f"wrote {destination}")
