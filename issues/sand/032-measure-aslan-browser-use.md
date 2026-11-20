---
title: Measure Aslan Browser use before retiring it
status: ready-for-agent
type: issue
category: migration
labels:
  - sand
  - aslan-browser-retirement
  - observability
created: 2026-11-20
---

## Parent

- `issues/sand/prd-retire-aslan-browser.md`

## What to build

Put a thin wrapper in front of the `aslan` CLI on both machines that appends one JSON line per call to `~/.local/state/aslan-browser/usage.jsonl`: time, machine, command, target host (from `nav` URLs and the current tab), and the calling Worker or skill when known (`PI_SUBAGENT_NAME`, cwd). It must not change behaviour or output. Add a one-line weekly summary command (`jq`) to the PRD's Further Notes.

## Acceptance criteria

- [ ] Every `aslan` call on the MacBook and the Mini appends one JSON line; output and exit codes are unchanged.
- [ ] A failed write to the log never fails the `aslan` call.
- [ ] A summary shows calls per command, per host and per caller for a date range.
- [ ] Installed through dotfiles bootstrap, so both machines get it.

## Blocked by

- None; can start now.
