---
title: sand-browser: type, select, key chords, scroll, waits, history
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

Add the interaction commands Aslan playbooks use: `type <target> <text>` (keyboard input, for contenteditable editors such as LinkedIn and Facebook), `select <target> <value>`, `key <chord>` (`Control+Shift+g`, `Meta+a`), `scroll [--down px|--up px|--to target]`, `wait --idle|--load [--timeout ms]`, `back`, `forward`, `reload`, and `open <url> --wait idle|load`.

## Acceptance criteria

- [x] Each command works by selector and by `@ref`.
- [x] `type` enters text into a contenteditable element; `fill` keeps working for inputs.
- [x] Each acting command records the last agent action and is refused while held.
- [x] Smoke test exercises each command on a local page.

## Blocked by

- `issues/sand/032-measure-aslan-browser-use.md`

## Progress

### 2026-11-20 — Aslan interaction parity, smoke-tested

Added `type` (focus, caret to the end, CDP `insertText`, like Aslan's `execCommand("insertText")`), `select` (`selectOption`, by value or label), `key <chord>` with Aslan's `--meta/--ctrl/--shift/--alt` flags (`press` stays as an alias), `scroll [--down|--up|--to]` (mouse wheel over the page centre, default 600 px; prints the scroll position), `wait [--idle|--load|--for <target>] [--timeout]`, `back`, `forward`, `reload`, `open --wait load|idle`. Beyond the issue, so that Aslan playbooks translate without edits: `title`, `url`, `wait --for` (Aslan `tab:wait`), and `eval` accepts a function body with `return` (Aslan's form) as well as an expression, retrying as an async body only when the expression fails to parse.

Finding: `page.goBack()` over `connectOverCDP` hangs forever when Chrome restores the page from the back/forward cache, and `page.title()` hangs on it afterwards. `back`/`forward` therefore use CDP `Page.navigateToHistoryEntry`, poll the history index and read title/URL from `Target.getTargetInfo`.

Verified: smoke "type into contenteditable -> ok", "select, key chords, scroll, wait, history -> ok", "eval bodies, title, url, wait for an element -> ok"; all acting commands are refused while held (they go through the existing held check and record the last action). Also fixed a SIGPIPE in the smoke script's existing `ldconfig -p | grep -q` line (exit 141 under `pipefail`).
