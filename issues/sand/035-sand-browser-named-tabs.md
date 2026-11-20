---
title: sand-browser: named tabs
status: done
type: issue
category: migration
labels:
  - sand
  - aslan-browser-retirement
  - browser-sandbox
  - agent-cli
created: 2026-11-20
---

## Parent

- `issues/sand/prd-retire-aslan-browser.md`

## What to build

Add `tab-new <name> [url]`, `tab-use <name>`, `tab-close [name]` and names in `tabs`, so agents can research across sites without overwriting the page Onur left open. Without a name, commands keep today's rule (newest tab). Names live in a small file in Guest State, keyed by CDP target id, so they survive the CLI exiting.

## Acceptance criteria

- [x] `--tab <name>` works on every command, next to `--tab <index>`.
- [x] Names survive between `sand-browser` calls and are dropped when the tab closes.
- [x] `activity` reports tab names, so Ops can show them.

## Blocked by

- `issues/sand/032-measure-aslan-browser-use.md`

## Progress

### 2026-11-20 — named tabs, smoke-tested

`tab-new <name> [url]`, `tab-use <name|N>`, `tab-close [name|N]`, and `--tab <name>` beside `--tab <index>` on every command. Names and the default tab live in `/state/sandbox/sand-browser-tabs.json` (Guest State; `SAND_BROWSER_TAB_NAMES` overrides), keyed by CDP target id (`Target.getTargetInfo`); names of closed tabs are dropped whenever tabs are listed or changed. `tabs` prints the name as a fourth column; `activity` gives each tab a `name`. `tab-new` refuses a name that is already open. The default tab is the one `tab-new`/`tab-use`/`open --new` chose while it is open, otherwise the newest, as before. Finding: `context.pages()` order after reconnecting is not creation order, so "newest" was already unreliable; named tabs are the dependable way.

Verified: smoke "named tabs -> ok".
