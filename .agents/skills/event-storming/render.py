#!/usr/bin/env python3
"""Render an event storming board spec (JSON) to a self-contained HTML file.

Usage: render.py SPEC.json [-o OUT.html] [--business]
Default OUT is SPEC with .html. --business drops code names (for product owners).
"""
import argparse
import html
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
MAX_SLOTS = 8  # what fits a 1440px viewport without scrolling the board

KINDS = {
    "actor": "Actor", "command": "Command", "aggregate": "Aggregate", "event": "Event",
    "policy": "Policy", "readmodel": "Read model", "external": "External system", "hotspot": "Hotspot",
}
LEGEND = [("event", "Domain event"), ("command", "Command"), ("aggregate", "Aggregate"),
          ("policy", "Policy (whenever … then …)"), ("readmodel", "Read model"), ("actor", "Actor"),
          ("external", "External system"), ("hotspot", "Hotspot / risk")]
LANE_KINDS = {None, "request", "job"}


class SpecError(Exception):
    pass


def inline(text):
    """Escape text; render `code` and [label](href)."""
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    return re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", lambda m: f'<a href="{html.escape(m[2])}">{m[1]}</a>', out)


def sticky(s, where, business):
    kind = s.get("type")
    if kind not in KINDS:
        raise SpecError(f"{where}: unknown type {kind!r}; use one of {', '.join(KINDS)}")
    if not s.get("title"):
        raise SpecError(f"{where}: sticky without title")
    copy = s.get("copy", False)
    if copy and kind != "event":
        raise SpecError(f"{where}: only events can be copies")
    classes = ["sticky", kind] + (["copy"] if copy else [])
    parts = [f'<span class="k">{KINDS[kind]}</span>']
    if copy:
        parts.append('<span class="copytag">same event</span>')
    parts.append(f"<p>{inline(s['title'])}</p>")
    if s.get("code") and not business:
        parts.append(f"<code>{html.escape(s['code'])}</code>")
    if s.get("detail"):
        parts.append(f"<small>{inline(s['detail'])}</small>")
    return f'<div class="{" ".join(classes)}">{"".join(parts)}</div>'


def lane(l, where, business):
    if not l.get("title"):
        raise SpecError(f"{where}: lane without title")
    if l.get("kind") not in LANE_KINDS:
        raise SpecError(f"{where}: kind must be 'request', 'job' or omitted")
    slots = l.get("slots") or []
    if not slots:
        raise SpecError(f"{where}: lane without slots")
    if len(slots) > MAX_SLOTS:
        print(f"warning: {where} has {len(slots)} slots; more than {MAX_SLOTS} scrolls at 1440px. "
              "Split the lane at a transaction or job boundary.", file=sys.stderr)
    cells = []
    for i, slot in enumerate(slots):
        if isinstance(slot, dict):
            slot = [slot]
        main = [st for st in slot if st.get("type") != "hotspot"]
        stickies = main + [st for st in slot if st.get("type") == "hotspot"]
        fan = " fan" if len(main) > 1 else ""
        body = "".join(sticky(st, f"{where} slot {i + 1}", business) for st in stickies)
        if i:
            cells.append('<div class="arrow" aria-hidden="true"></div>')
        cells.append(f'<div class="slot{fan}">{body}</div>')
    kind = f' lane-{l["kind"]}' if l.get("kind") else ""
    tag = f'<span class="lane-tag">{html.escape(l["tag"])}</span>' if l.get("tag") else ""
    sub = f'<p>{inline(l["sub"])}</p>' if l.get("sub") else ""
    return (f'<section class="lane{kind}">\n  <header class="lane-head">{tag}<h2>{inline(l["title"])}</h2>{sub}</header>\n'
            f'  <div class="flow">{"".join(cells)}</div>\n</section>')


def board(items, business):
    out = []
    for n, item in enumerate(items, 1):
        if "between" in item:
            out.append(f'<p class="between">{inline(item["between"])}</p>')
        elif "parallel" in item:
            lanes = "\n".join(lane(l, f"parallel {n} lane {i}", business) for i, l in enumerate(item.get("lanes", []), 1))
            out.append(f'<div class="parallel">\n<span class="parallel-label">{inline(item["parallel"])}</span>\n{lanes}\n</div>')
        else:
            out.append(lane(item, f"lane {n} ({item.get('title', '?')})", business))
    return "\n".join(out)


def all_stickies(items):
    for item in items:
        for l in item.get("lanes", [item]):
            for slot in l.get("slots", []):
                yield from ([slot] if isinstance(slot, dict) else slot)


def card(title, items, risk=False):
    lis = "".join(f"<li>{inline(i)}</li>" for i in items)
    return f'<section class="card{" risk" if risk else ""}"><h2>{inline(title)}</h2><ul>{lis}</ul></section>'


def git_line():
    def git(*args):
        return subprocess.run(["git", *args], capture_output=True, text=True).stdout.strip()
    branch, sha = git("branch", "--show-current"), git("rev-parse", "--short=10", "HEAD")
    return f"Branch `{branch}` at `{sha}`. " if branch and sha else ""


def render(spec, business):
    items = spec.get("board") or []
    if not spec.get("title") or not items:
        raise SpecError("spec needs 'title' and a non-empty 'board'")
    stickies = list(all_stickies(items))
    reading = ["Each lane is one unit of work: a request, a transaction or a job. Time flows left to right."]
    if any(s.get("copy") for s in stickies):
        reading.append("A faded event tagged “same event” is the event from an earlier lane that starts this one.")
    if not business:
        reading.append("Policies are the event handlers; the class is on the sticky.")
    hotspots = spec.get("hotspots") or [s["title"] for s in stickies if s.get("type") == "hotspot"]
    cards = [card("How to read it", reading)]
    cards += [card(c["title"], c["items"], c.get("risk", False)) for c in spec.get("cards", [])]
    if hotspots:
        cards.append(card("Hotspots in one place", hotspots, risk=True))
    lede = ("" if business else git_line()) + spec.get("lede", "")
    legend = "".join(f'<span><i class="swatch {k}"></i>{t}</span>' for k, t in LEGEND)
    css = (HERE / "board.css").read_text()
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(spec["title"])}</title>
<style>
{css}</style>
</head>
<body>
<main>
  <div class="top">
    <h1>{inline(spec["title"])}</h1>
    <p class="lede">{inline(lede)}</p>
    <div class="legend">{legend}</div>
  </div>
  <div class="board">
    <div class="board-inner">
      <div class="timeline">time →</div>
{board(items, business)}
    </div>
  </div>
  <div class="reading">
{chr(10).join(cards)}
  </div>
</main>
</body>
</html>
"""


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("spec", type=Path)
    ap.add_argument("-o", "--out", type=Path)
    ap.add_argument("--business", action="store_true", help="hide code names, for product owners")
    args = ap.parse_args()
    out = args.out or args.spec.with_suffix(".html")
    try:
        page = render(json.loads(args.spec.read_text()), args.business)
    except (SpecError, json.JSONDecodeError) as err:
        sys.exit(f"{args.spec}: {err}")
    out.write_text(page)
    print(out)


if __name__ == "__main__":
    main()
