---
title: Switch every Aslan consumer to Browser Sandboxes
status: ready-for-agent
type: issue
category: migration
labels:
  - sand
  - aslan-browser-retirement
  - skills
  - migration
created: 2026-11-20
---

## Parent

- `issues/sand/prd-retire-aslan-browser.md`

## What to build

Move each consumer found in the PRD inventory: `looker-studio-report-fixer` (SKILL.md and `scripts/looker-ui.sh`: `aslan nav/eval/key/tree` → `sand run <client> sand-browser …`), `web-search` and `dotfiles/pi/AGENTS.md` escalation (client's Browser Sandbox, else `web`), Google Business photo uploads (`upload-put` + `upload`), and the user preferences in Aslan's `knowledge/user.md`.

## Acceptance criteria

- [ ] `grep -r "aslan "` over skills, toolshed and dotfiles finds no live call outside `skills/aslan-browser`.
- [ ] The Looker Studio fixer completes one real report fix in a Browser Sandbox.
- [ ] The 032 log shows no calls from switched consumers.

## Blocked by

- `issues/sand/036-sand-browser-skill-and-knowledge.md`
- `issues/sand/037-client-browser-sandboxes.md`
