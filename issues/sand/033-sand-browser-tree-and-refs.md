---
title: sand-browser: accessibility tree with element refs
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

Add `sand-browser tree` printing `page.ariaSnapshot({ mode: 'ai' })` (refs like `[ref=e3]`), and let every action that takes a selector accept `@e3`, resolved as `aria-ref=e3`. This is Aslan's `aslan tree` / `aslan click @e3` contract, which most playbooks rely on.

## Acceptance criteria

- [x] `sand-browser tree` prints the AI-mode snapshot with refs for the chosen tab.
- [x] `click`, `fill`, `upload` and new commands accept `@eN` refs.
- [x] A stale ref (after navigation) fails with a message telling the agent to run `tree` again.
- [x] `tree` is a looking command (allowed while Onur has control); acting with a ref is not.
- [x] Definition test and smoke test cover tree + click-by-ref + fill-by-ref.

## Blocked by

- `issues/sand/032-measure-aslan-browser-use.md`

## Progress

### 2026-11-20 — tree and refs, smoke-tested

`sand-browser tree` prints `page.ariaSnapshot({ mode: 'ai' })`. Finding: Playwright's refs (`aria-ref=e3`) live only as long as one CDP connection, and every `sand-browser` call is its own connection, so a later `click @e3` could never resolve them (checked against Chrome in the image: timeout). Also, refs can get a frame prefix (`f1e13`) that depends on the connection. So `tree` also tags each element it printed a ref for with `data-sand-ref` (clearing an earlier tree's tags first), and `@e3` resolves by that tag in any frame. Element identity is exact; navigation or a re-render removes the tag, and the action fails with "…run sand-browser tree again" (exit 1). `click`, `fill`, `type`, `select`, `scroll --to`, `wait --for` and `upload` take refs. `tree` is a looking command.

Verified: `BrowserImageDefinitionTests` (6 tests) and `scripts/smoke-browser-image.sh` pass on the Mini (Docker, Google Chrome amd64): "tree, click and fill by ref -> ok", "stale ref refused -> ok". `make check` passes.

### 2026-11-20 — refs on big pages

First real use (Google Maps, 445 refs) tagged nothing: Playwright resolves `aria-ref=eN` one at a time (~10 ms each), so the parallel tagging timed out. `tree` now writes all tags in one pass inside Playwright's isolated world, where the snapshot left each element's ref as `element._ariaRef`, found over CDP by its name `__playwright_utility_world_<page guid>`. If a later Playwright renames it, the CLI falls back to the utility world whose refs best match the snapshot, then to resolving up to 40 missing refs one by one (also covers frames in another process). Maps: 445 refs in ~1 s. Also found: every `sand-browser` call leaves one Playwright utility world in the page until it navigates (60 on a long-lived Maps tab), which is Playwright-over-CDP behaviour, not new here. Smoke: "refs on a big page -> ok" (400 buttons).

