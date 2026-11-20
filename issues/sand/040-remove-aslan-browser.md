---
title: Remove Aslan Browser
status: ready-for-agent
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
