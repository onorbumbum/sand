# Start/Stop/Delete Guest State Validation

Date: 2026-05-18 23:05 local

Conclusion: **PASS — `sand start`, `sand stop`, and `sand delete` work against the real Apple backend while preserving Guest State across stop/start and deleting Host Metadata/backend state only after confirmation or `--force`.**

Raw evidence: `docs/validation/start-stop-delete-guest-state/run-20260518-230533.log`

## Scenario

- Sandbox Name: `sand-tdd-230533`
- Sandbox Image: `sand/developer-ready:ubuntu-lts`
- Resource Profile: 2 CPUs, 1GB memory
- Backend: Apple `container` CLI

## Requirement results

| Requirement | Result | Evidence summary |
|---|---:|---|
| `sand <name> start` starts the real Sandbox VM | PASS | `sand <name> status` reported `state: running` after start. |
| `sand <name> stop` stops without resetting Guest State | PASS | `sand <name> status` reported `state: stopped`; subsequent start preserved marker. |
| Marker in Guest State survives stop/start | PASS | Marker written to `/tmp/sand-marker-005`; post-restart command verified the same value. |
| `sand delete <name>` prompts by default | PASS | Piped `no` showed the destructive prompt and exited 1. |
| `sand delete <name> --force` skips confirmation | PASS | Forced delete exited 0 with no prompt. |
| Delete removes Host Metadata | PASS | `~/.sand/specs/sand-tdd-230533.yaml` was absent after forced delete. |
| Delete removes backend resources and Guest State | PASS | `container inspect sand-tdd-230533` returned `[]` after forced delete. |
| Concurrent Lifecycle Mutations are serialized | PASS | Deterministic test covers cross-instance file locking for shared Host Metadata root. |
| No separate `reset` command in v1 surface | PASS | Existing deterministic CLI tests reject `reset`. |
| Acceptance demonstrated against real Apple backend | PASS | No fake or in-memory backend was used in this validation run. |

## Deterministic test evidence

- `swift test` — 56 tests passing.
