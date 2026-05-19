# Run Opaque Workload Commands Validation

Date: 2026-05-18 23:14 local

Conclusion: **PASS — `sand <name> run <command> [args...]` executes opaque Workload Commands against the real Apple backend, auto-starts a stopped Sandbox VM, preserves workload arguments, supports redirected and TTY usage, and exposes missing-command failures clearly.**

Raw evidence: `docs/validation/run-opaque-workload-commands/run-20260518-231406.log`

## Scenario

- Sandbox Name: `sand-run-231406`
- Sandbox Image: `sand/developer-ready:ubuntu-lts`
- Resource Profile: 2 CPUs, 1GB memory
- Backend: Apple `container` CLI

## Requirement results

| Requirement | Result | Evidence summary |
|---|---:|---|
| `sand <name> run <command> [args...]` executes in the real Sandbox Guest | PASS | `python3`, `printf`, `/bin/sh`, and a missing command were executed through `.build/debug/sand <name> run ...` against a real Apple `container` runtime. |
| Running a command auto-starts a stopped Sandbox VM | PASS | Initial status was `state: stopped`; after the first `run`, status reported `state: running`. |
| Workload Command arguments pass through unchanged | PASS | Python printed `sys.argv[1:]` as `["--workload-flag", "--", "literal", "two words"]`. |
| Pi is not special-cased in parsing or execution | PASS | Deterministic CLI tests verify `pi --model gpt-5 -- literal` is passed as an opaque Workload Command; backend execution uses only generic command arguments. |
| Missing commands fail clearly | PASS | `definitely-not-installed-sand-006` exited nonzero and surfaced Apple backend stderr: `failed to find target executable definitely-not-installed-sand-006`. |
| `run` behaves naturally for redirected usage | PASS | Redirecting `sand ... run printf 'redirect-ok\n' > redirect.txt` wrote only `redirect-ok` to the file. |
| `run` behaves naturally for TTY usage | PASS | A `script`-allocated TTY ran `/bin/sh -lc 'test -t 0 && test -t 1 && echo TTY_OK'` and printed `TTY_OK`. |
| Acceptance demonstrated against real Apple backend | PASS | Validation used `.build/debug/sand` with the default `AppleContainerCLIBackend`; no fake/in-memory backend was used. |

## Deterministic test evidence

- `swift test` — 58 tests passing.
