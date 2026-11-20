---
title: Remove Aslan Browser
status: in-progress
type: issue
category: migration
labels:
  - sand
  - aslan-browser-retirement
  - migration
  - cleanup
created: 2026-11-20
---

## Parent

- `issues/sand/prd-retire-aslan-browser.md`

## What to build

After 14 consecutive days with zero `aslan` calls in the 032 log: remove the app and `aslan` links from both machines and from dotfiles bootstrap, remove the `skills/aslan-browser` symlink (the skill itself lives in the Aslan repo; its knowledge now lives in `skills/sand-browser`), archive `onorbumbum/aslan-browser` and `onorbumbum/aslan-browser-workspace` on GitHub (read-only, not deleted), drop them from `dotfiles/repos.txt`, and update the Ops system doc and Mini inventory.

## Acceptance criteria

- [ ] The usage log shows 14 quiet days before anything is removed.
- [ ] Neither machine has the app, the CLI or the skill; bootstrap does not reinstall them.
- [ ] Both repos are archived, not deleted.
- [ ] Docs that described Aslan as current now point to Browser Sandboxes.

## Blocked by

- `issues/sand/038-live-view-fill-login.md`
- `issues/sand/039-switch-aslan-consumers.md`

## Progress

### 2026-11-20 — The gate is automated and scheduled

- `dotfiles/bin/aslan-retire-check` (test: `dotfiles/tests/test-aslan-retire-check.sh`) answers the usage criterion per machine: exit 0 only when the `~/.local/bin/aslan` logging wrapper has been linked for at least 14 days and the usage log has no call in the last 14 days; otherwise it says why and names the last caller. On the Mini today: "not yet: logging since 2026-11-20".
- Ops task `UZ-4beff4d3f1` (due 2026-12-04, the earliest day the Mini can pass) runs it on both machines and either asks Onur to approve the removal or moves the remaining callers to sand-browser and sets the next check date.
- The MacBook only counts once `bootstrap.sh --role standby` has linked the wrapper there; its 14 days start then.
- Other exit criteria: consumers switched (039, waiting on one real Looker fix) and the top-five playbooks verified (036, waiting on real tasks).

