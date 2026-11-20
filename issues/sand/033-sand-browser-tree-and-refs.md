---
title: sand-browser: accessibility tree with element refs
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

Add `sand-browser tree` printing `page.ariaSnapshot({ mode: 'ai' })` (refs like `[ref=e3]`), and let every action that takes a selector accept `@e3`, resolved as `aria-ref=e3`. This is Aslan's `aslan tree` / `aslan click @e3` contract, which most playbooks rely on.

## Acceptance criteria

- [ ] `sand-browser tree` prints the AI-mode snapshot with refs for the chosen tab.
- [ ] `click`, `fill`, `upload` and new commands accept `@eN` refs.
- [ ] A stale ref (after navigation) fails with a message telling the agent to run `tree` again.
- [ ] `tree` is a looking command (allowed while Onur has control); acting with a ref is not.
- [ ] Definition test and smoke test cover tree + click-by-ref + fill-by-ref.

## Blocked by

- `issues/sand/032-measure-aslan-browser-use.md`
