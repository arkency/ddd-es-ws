---
name: event-storming
description: Render an event-sourced flow as an event storming board (HTML, swim lanes per request/job). Use when asked for event storming, or to show how a flow moves through commands, aggregates, events, handlers and background jobs.
---

A board is one JSON spec rendered by `render.py`. Keep the spec next to the HTML, edit the spec for every redraw, and re-render it. Write HTML only through `render.py`.

## 1. Trace the flow

Start at the entry point (GraphQL mutation, controller, command) and follow it until nothing new happens. For each event, find every subscriber by grepping the event class across the codebase, including `config/`. Wiring sits in `event_store.subscribe(...)` calls and in any per-domain subscription maps the project uses (check its `AGENTS.md`).

- Subscribed as an instance (`Handler.new`) or a lambda: **sync**. It runs in the publisher's transaction, so it stays in the same lane.
- Subscribed as a class (an ActiveJob, e.g. an `AsyncEventHandler` subclass): **async**. It starts a new lane after commit.

Done when every subscriber of every event on the board is either on the board or named in a card as out of scope.

## 2. Write the spec

Path: `tmp/show-me-<topic>-eventstorming.json`. [`examples/show-me-in-event-storming-format.json`](examples/show-me-in-event-storming-format.json) is a finished board for the demo app in `demo/` (desk booking, end to end); copy its shape.

| Code | Sticky `type` |
|---|---|
| User, scanner, client calling the API | `actor` |
| Mutation, controller action, `<Domain>::<Feature>::Command` | `command` |
| `AggregateRoot` class, or the record that enforces the rule | `aggregate` |
| `RubyEventStore::Event` | `event` |
| Event handler | `policy` |
| Projection, AR model the flow reads or writes, GraphQL query | `readmodel` |
| Third-party API, outbound message | `external` |
| Risk, missing invariant, silent stop, vestigial step | `hotspot` |

A sticky is `{"type", "title", "code", "detail", "copy"}`:
- `title`: plain English. For a policy, write it as "Whenever <event>, <reaction>".
- `code`: the class, mutation or query name.
- `detail`: one short line, e.g. a key field, a guard or "sync · same transaction".

`` `x` `` renders as code and `[label](href)` as a link in every text field.

Layout rules:
- **One lane per unit of work.** A request, a transaction or a job each get a lane. The lane's `sub` says which, and when it runs ("async job, after commit"). Set `kind` to `request` (blue edge) or `job` (orange edge).
- A slot is one sticky, or a list of stickies stacked in one column. Stack two subscribers of one event this way (a fan-out), and stack a hotspot under the sticky it is about.
- **An async lane opens with the triggering event as a copy** (`"copy": true`, detail "from the <lane>"), followed by the policy that subscribes to it.
- Put `{"between": "transaction commits · two jobs start"}` where control passes from a request to its jobs.
- Wrap jobs with no ordering between them in `{"parallel": "A and B run in parallel · no ordering between them", "lanes": [...]}` and give them `tag` letters. Put ordering hazards in hotspots.
- Keep a lane to 8 slots or fewer so it fits 1440px. `render.py` warns above that. Split such a lane at a transaction or job boundary.
- `hotspots` (top level) is the summary card. Write full sentences there. When omitted, the hotspot titles are used. `cards` adds extra `{"title", "items", "risk"}` cards.

## 3. Render and check

```bash
python3 .agents/skills/event-storming/render.py tmp/show-me-<topic>-eventstorming.json
```

Without `-o`, the HTML goes next to the spec. The lede starts with the branch and short SHA when run inside a git repo. `--business` hides `code` names and the git line, for product owners; keep every title in business terms then.

Open the HTML at 1440×900 and at 1280×800 and evaluate [`probe.js`](probe.js) in each.
- Done when `overflowingStickies` is empty and `pageScrollsSideways` is false at both sizes, and `boardScrollsSideways` is false at 1440.
- If a sticky overflows, shorten its `title` or `detail`. A long class name in `code` wraps on its own.

Then run `open <html>` and reply with the path plus the hotspots, one line each.
