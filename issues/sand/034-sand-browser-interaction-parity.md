---
title: sand-browser: type, select, key chords, scroll, waits, history
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

Add the interaction commands Aslan playbooks use: `type <target> <text>` (keyboard input, for contenteditable editors such as LinkedIn and Facebook), `select <target> <value>`, `key <chord>` (`Control+Shift+g`, `Meta+a`), `scroll [--down px|--up px|--to target]`, `wait --idle|--load [--timeout ms]`, `back`, `forward`, `reload`, and `open <url> --wait idle|load`.

## Acceptance criteria

- [ ] Each command works by selector and by `@ref`.
- [ ] `type` enters text into a contenteditable element; `fill` keeps working for inputs.
- [ ] Each acting command records the last agent action and is refused while held.
- [ ] Smoke test exercises each command on a local page.

## Blocked by

- `issues/sand/032-measure-aslan-browser-use.md`
