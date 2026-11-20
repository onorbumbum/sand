---
title: sand-browser skill: carry over Aslan's knowledge
status: ready-for-agent
type: issue
category: migration
labels:
  - sand
  - aslan-browser-retirement
  - skills
  - knowledge
created: 2026-11-20
---

## Parent

- `issues/sand/prd-retire-aslan-browser.md`

## What to build

Create `skills/sand-browser/` (SKILL.md with the interactive driving protocol and knowledge-compilation rule from Aslan, adapted) and copy `knowledge/core.md`, `knowledge/sites/` and `knowledge/playbooks/` from `skills/aslan-browser/` (a symlink into the Aslan repo, so this copy is what keeps the knowledge after retirement; `knowledge/user.md` is gitignored there and must be copied by hand), rewriting every command to `sand run <box> sand-browser …`. Verify playbooks by running them; start with the five most used according to the 032 log.

## Acceptance criteria

- [ ] Every Aslan site note and playbook exists in the new skill with `sand-browser` commands.
- [ ] Each playbook states at the top whether it is verified in a Browser Sandbox (date, sandbox) or not yet.
- [ ] The five most-used playbooks (by the 032 log) are verified.
- [ ] Aslan-only notes (WKWebView quirks, `https://`-only, ATS) are dropped, not copied.

## Blocked by

- `issues/sand/033-sand-browser-tree-and-refs.md`
- `issues/sand/034-sand-browser-interaction-parity.md`
- `issues/sand/035-sand-browser-named-tabs.md`
