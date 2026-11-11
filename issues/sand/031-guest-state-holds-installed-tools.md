---
title: Guest State holds installed tools, so a Linux Sandbox VM is a computer that keeps what it installs
status: open
type: issue
category: enhancement
labels:
  - ready-for-agent
  - sand
  - sandbox-vm
  - linux
  - apple-container
  - guest-state
created: 2026-10-09
---

## Why

`issues/sand/CONTEXT.md` defines **Guest State** as "the persistent filesystem state owned by the Sandbox Guest, including installed tools, shell config, package caches, and sandbox-local app config." On Linux that is only half true today: files under `/state` persist, but anything installed the ordinary way (`sudo apt install ffmpeg`, `npm i -g`, `pip install --user`, `~/.config/*`) lands in the container rootfs or in `/home/sandbox`, and both are rebuilt from the Base Image whenever the Runtime Instance is recreated.

The consumer driving this is Ipso (`~/_PROJECTS/ipso`). Ipso is moving toward one long-lived Linux Sandbox VM, called "Ipso's computer", that works the way a regular computer does. An agent installs a tool once, and it is still there next week, after restarts and after spec changes. This removes the need to re-provision tools inside every job. It also means an agent that fixes a broken job by installing something does not lose that fix silently on the next recreate.

The goal: **anything a guest installs or configures as the `sandbox` user survives `stop`/`start` and Runtime Instance recreation, and is usable from a plain `sand run <name> <cmd>` with no login shell.**

## Facts established before writing this (verify, don't re-derive)

- **Recreation is routine.** `AppleContainerCLIBackend.apply` (`Sources/SandCore/Backend/AppleContainerCLIBackend.swift`, `apply(_:)`) stops the runtime, runs `container delete --force`, then `container create`s a fresh runtime from the Base Image with the same `<name>` Guest State volume at `/state`. Every `sand apply` that changes the spec, such as a shared folder, recreates the runtime.
- **Only `/state` survives recreation.** This is validated in `docs/validation/apple-container-backend/RESULTS.md` and `docs/validation/declarative-spec-apply/RESULTS.md`. Nobody has recorded whether rootfs changes survive a plain `stop`/`start`; measure it (step 0 below).
- **`sand run` does not start a login shell.** It is `container exec --interactive [--tty] --user sandbox --workdir <dir> <name> <command...>` (`execArguments`). `/etc/profile`, `/etc/profile.d/*` and `~/.bashrc` are **not** read. PATH and other environment variables must come from the image (`ENV`), or from what `container exec` derives from `/etc/passwd` (e.g. HOME). Ipso calls `sand run` this way in production.
- **The Base Image already uses the pattern this issue generalizes.** `images/developer-ready/Dockerfile` symlinks `/home/sandbox/.pi` → `/state/sandbox/.pi` and `/home/sandbox/.sand-secrets` → `/state/sandbox/secrets`. The symlinks live in the image, so they survive recreation; their targets live on `/state`.
- **The `sandbox` user's home is `/home/sandbox` (rootfs).** Everything there except the two symlinks is lost on recreate.

## What to build

One rule, enforced by the Base Image:

> **The image provides only bootstrap tools and pointers. Everything the guest installs or configures lives under `/state`.**

### 1. The `sandbox` user's home lives on Guest State

Make the `sandbox` user's home directory persistent: `/state/sandbox`, or a dedicated `/state/sandbox/home` if mixing with existing `/state/sandbox` contents is a problem. Pick one and justify it in the Progress log. Then `~/.local`, `~/.config`, `~/.cache`, `~/.npm-global`, uv tool installs and shell config all persist with no per-tool symlinks.

- Prefer changing the user's home in the image (`useradd --home-dir ...` / `usermod -d`) over adding symlinks.
- First start on an empty volume needs the home seeded (skel files, ownership). Existing volumes already contain `/state/sandbox/.pi` and `/state/sandbox/secrets`, and seeding must not clobber them. Seeding should be idempotent.
- Verify that `container exec --user sandbox` actually sets `HOME` from `/etc/passwd`. If it does not, set HOME through the backend's exec arguments. Do not rely on a login shell.
- Keep `.pi` and `.sand-secrets` working at the paths existing guests and docs use.

### 2. User-level package managers install into the persistent home

- **Python:** `uv` available (in the image or installed into the persistent home; decide and record). Scripts declare dependencies inline (PEP 723) and run with `uv run`. `uv tool install` puts binaries in `~/.local/bin`.
- **Node:** an npm global prefix in the persistent home (e.g. `~/.npm-global`) so `npm i -g` persists.
- **PATH:** set in the image with `ENV PATH=...`, using **absolute** paths into the persistent home, because nothing sources a profile. `ENV` does not expand `$HOME` at exec time.

### 3. System tools (ffmpeg and anything else apt would provide)

apt installs into `/usr` by design, so it cannot persist on its own. Run a short, timeboxed spike and pick **one** mechanism. Record the evidence in the Progress log:

| Candidate | How it persists | Known risk to check first |
|---|---|---|
| **Homebrew on Linux** (default candidate) | Image symlinks `/home/linuxbrew` → `/state/linuxbrew`; brew installs there | Brew needs the `/home/linuxbrew/.linuxbrew` prefix to pour bottles. Check whether it accepts a symlinked prefix or falls back to slow source builds. Same `brew install` commands as on the Host Mac, which helps agents. |
| **Nix** | Store lives on Guest State | Nix refuses a symlinked `/nix`. It would need a second volume mounted at `/nix`, which is a spec/backend change. It does give rollback via generations. |
| **apt replay** | A package list on `/state` is replayed on start when missing | Simple and uses stock packages. Costs reinstall time after each recreate, and needs a start hook Sand does not have today. |

**Choose by:** `ffmpeg -version` works from a plain `sand run` after a recreate, with no reinstall step. Prefer the fewest new moving parts in Sand. Prefer prebuilt binaries over source builds. If Homebrew meets the bar, take it and don't build the others.

### 4. Measure first (step 0, before changing anything)

On a throwaway sandbox, record whether a rootfs change (e.g. `sudo touch /usr/local/marker`) survives `sand stop` + `sand start`. This decides how often recreation actually costs anything, and the answer belongs in the README's persistence section either way.

## Acceptance criteria

- [ ] A validation script under `docs/validation/guest-state-installed-tools/` (same style as the existing `validate.sh` + `RESULTS.md` + run log), run on a **throwaway** sandbox, shows each of the following working via plain `sand run <name> <cmd>` (no `bash -lc`) **after `stop`/`start` and again after a spec change + `sand apply` recreation**:
  - [ ] a system tool installed by the chosen mechanism (`ffmpeg -version`)
  - [ ] a Python script with an inline-declared third-party dependency, via `uv run`
  - [ ] a `uv tool install`ed CLI on PATH
  - [ ] an `npm i -g` CLI on PATH
  - [ ] a file in `~/.config/` and a line in `~/.bashrc`
  - [ ] `~/.pi` and `~/.sand-secrets` still resolve to their `/state` targets
- [ ] After recreation, none of the above was reinstalled. Prove it with timestamps or install markers, not just "the command worked."
- [ ] Seeding a fresh, empty Guest State volume works, and running it twice is a no-op.
- [ ] An existing sandbox created from the previous image, with `.pi` and `secrets` already on `/state`, upgrades through `sand apply` without losing either. Test this on a throwaway sandbox created from the old image first.
- [ ] `sand delete` still removes the Guest State volume, and everything installed with it.
- [ ] Step 0's stop/start rootfs result is recorded.

## Definition of Done

- [ ] `make check` passes. Backend behavior changes, if any (e.g. HOME in exec args, an extra volume), have unit tests at the existing seams.
- [ ] README "Persistence expectation" section, Onboarding Guide and Developer Guide state the rule: the image provides pointers, installs live in Guest State. They name the chosen system-tool mechanism and what still does **not** persist (anything a guest writes outside the persistent home and the chosen prefix, e.g. `sudo apt install`). `make docs-check` passes.
- [ ] `issues/sand/CONTEXT.md` Guest State definition matches the delivered behavior exactly. Edit it if the delivered scope is narrower.
- [ ] The decision for section 3 and its evidence are written in this issue's Progress log, including the rejected candidates and why.

## Constraints

- **Do not touch `ipso-blog-computer`.** It is Ipso's production sandbox. Applying the new image to it means a recreate, which interrupts work in flight. Onur decides when that happens, after this issue is done. Use throwaway sandbox names (e.g. `sand-gs-<timestamp>`) and delete them when finished.
- Do not use `sand doctor` as a read-only probe. Its readiness checks can auto-start Apple's container service.
- `sand run` does not invoke a shell. Use `sand run <name> sh -c "..."` whenever a validation step needs pipes, redirects or `&&`.
- No new long-running agents, daemons or services in the guest. Persistence has to come from where things live, not from a process that restores them.
- Linux only. macOS guests (Tart) already keep their whole disk and need no change.

## Out of scope

- Snapshots or rollback of Guest State. This would be a natural follow-up (snapshot the volume before an agent changes the computer), but it is not part of this issue.
- Making `sudo apt install` persist. It's fine for it to remain documented as non-persistent.
- Ipso-side changes (migrating `ipso-blog-computer`, removing per-job tool provisioning). Those are a separate Ipso issue once this lands.
- Updating the image's pi package. The image still installs `@mariozechner/pi-coding-agent@0.73.1`; current releases are `@earendil-works/pi-coding-agent`. This is a known stale dependency; note it, but fix it in its own issue.

## Progress

_(append dated entries here)_
