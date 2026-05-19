# Shell Sessions as Sandbox User — Validation Results

Date: 2026-05-18
Backend: Apple `container` CLI 0.12.3
Sandbox image: `sand/developer-ready:ubuntu-lts`
Raw log: `run-20260518-232548.log`

## Result

PASS.

## Evidence

The validation script built `sand`, created a real Sandbox VM named `sand007shell`, and opened two `sand sand007shell shell` sessions through tmux against the Apple backend.

Observed in both sessions:

- Shell prompt opened directly in the guest with no login prompt.
- `whoami` returned `sandbox`.
- `sudo -n whoami` returned `root`, proving passwordless sudo without a password prompt.
- `test -t 0` returned `yes`, proving the session had a TTY.
- Both sessions ran concurrently: session two completed while session one was still sleeping.

Deterministic tests also passed:

```text
swift test — 58 tests, 0 failures
```
