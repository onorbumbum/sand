---
title: Measure Aslan Browser use before retiring it
status: done
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

- [x] Every `aslan` call on the MacBook and the Mini appends one JSON line; output and exit codes are unchanged.
- [x] A failed write to the log never fails the `aslan` call.
- [x] A summary shows calls per command, per host and per caller for a date range.
- [x] Installed through dotfiles bootstrap, so both machines get it.

## Blocked by

- None; can start now.

## Progress

### 2026-11-20 — Usage log live on the Mini

`dotfiles/bin/aslan-logged`, linked as `~/.local/bin/aslan` through `links.txt` (first on PATH, ahead of the real `/usr/local/bin/aslan`), runs the real `aslan` with the same stdin, stdout, stderr and exit code, then logs in the background: `ts`, `machine`, `cmd`, `host` (from a URL argument, else the current tab's `aslan url`, 3 s cap), `session`, `exit`, `ms`, `worker` (`PI_SUBAGENT_NAME`), `skill` (from the calling script's `/skills/<name>/` path or cwd), `parent`, `cwd`. A missing `jq` or an unwritable log only skips the line. `dotfiles/bin/aslan-usage [--since] [--until]` summarises per command, host, caller and machine.

Verified: `dotfiles/tests/test-aslan-usage.sh` 23/23 (fake aslan: output, stderr, stdin, exit codes, host, Worker, skill, unwritable log, summary date range); a real `aslan status` on the Mini logged. `bootstrap.sh --role primary --dry-run` reports `ok ~/.local/bin/aslan`. `system.md` section 6 updated. The MacBook gets the link on its next `bootstrap.sh --role standby`. (`tests/test-bootstrap.sh` has 3 failures that predate this change.)
