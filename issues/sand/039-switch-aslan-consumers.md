---
title: Switch every Aslan consumer to Browser Sandboxes
status: in-progress
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

- [x] `grep -r "aslan "` over skills, toolshed and dotfiles finds no live call outside `skills/aslan-browser`.
- [ ] The Looker Studio fixer completes one real report fix in a Browser Sandbox.
- [x] The 032 log shows no calls from switched consumers.

## Blocked by

- `issues/sand/036-sand-browser-skill-and-knowledge.md`
- `issues/sand/037-client-browser-sandboxes.md`

## Progress

### 2026-11-20 — Consumers switched; one real Looker fix still to run

- `looker-studio-report-fixer`: `scripts/looker-ui.sh` drives the client's Browser Sandbox (`LOOKER_BOX=<client id lowercased>`, named tab `looker`, `sand run … sand-browser eval --raw`); ungroup is Ctrl+Shift+G (Linux Chrome) instead of Cmd+Shift+G. SKILL.md and conventions.md open the report with `tab-new looker` + `open --wait load --tab looker`. Checked in `web` against a page shaped like a report: audit, select, verify (pass and fail) and cleanup-overlays return the JSON the skill reads with jq; a missing `LOOKER_BOX` exits 2 with a clear message.
- `sand-browser eval --raw` added (strings printed as is, as Aslan did); the reviews playbook's scroll loop uses it.
- `web-search` and `dotfiles/pi/AGENTS.md` already escalated to Browser Sandboxes (earlier commits). Google Business photo uploads: `knowledge/user.md` and the GBP playbooks use `upload-put` + `upload` (036). Aslan's user preferences are in `skills/sand-browser/knowledge/user.md`.
- Grep over skills, toolshed and dotfiles: no live `aslan <command>` call outside `skills/aslan-browser` (the usage-logging wrapper and its test aside).

### 2026-11-20 — Usage log checked after the switch

`aslan-usage --since 2026-11-20` on the Mini: 12 calls, all with caller `zsh`, between 18:09Z and 18:16Z, from the parity comparison during 033–035 (before the consumers were switched). None from `looker-studio-report-fixer`, `web-search` or Pi, and no call at all after 18:16Z. They do not move the removal gate (`aslan-retire-check` counts only days after 2026-11-20). The quiet period keeps checking this (040).

## Waiting on Onur

- One real Looker Studio fix in a client's sandbox, signed in to that client's Google account (037), to tick the second criterion.

