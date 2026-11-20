---
title: sand-browser: named tabs
status: ready-for-agent
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

- [ ] `--tab <name>` works on every command, next to `--tab <index>`.
- [ ] Names survive between `sand-browser` calls and are dropped when the tab closes.
- [ ] `activity` reports tab names, so Ops can show them.

## Blocked by

- `issues/sand/032-measure-aslan-browser-use.md`
