# Shared Folder Lifecycle and Policy Validation

Date: 2026-05-18 23:38 local

Conclusion: **PASS — `sand folders add/list/remove` updates the Sandbox Spec, applies real Apple backend mount configuration, and enforces read-write/read-only behavior with Host-Safe File Ownership.**

Raw evidence: `docs/validation/shared-folder-lifecycle-policy/run-20260518-233846.log`

Harness: `docs/validation/shared-folder-lifecycle-policy/validate.sh`

## Scenario

- Sandbox Name: `sand-af-233846`
- Sandbox Image: `sand/developer-ready:ubuntu-lts`
- Resource Profile: 2 CPUs, 1GB memory
- Backend: Apple `container` CLI
- Host test root: `/tmp/sand-shared-folder-sand-af-233846`

## Requirement results

| Requirement | Result | Evidence summary |
|---|---:|---|
| `sand folders add <name> <host-path> rw|ro|read-write|read-only` works | PASS | Added read-write folder using `rw`, updated it using `read-write`, and added read-only folder using `ro`/`read-only`. |
| `sand folders list <name>` shows host path, Guest Path, and Access Mode | PASS | Output included `Host Path`, `Guest Path`, `Access Mode`, `/code`, `/reference`, `read-write`, and `read-only`. |
| `sand folders remove <name> <host-path>` removes and applies | PASS | Removed read-only folder, verified `/reference` disappeared from spec, then re-added it. |
| `rw` and `ro` normalize to canonical spec values | PASS | Spec contained `accessMode: read-write` and `accessMode: read-only`. |
| Default Guest Paths derive under `/workspace` | PASS | Initial add produced `guestPath: /workspace/rw`. |
| `--as <guest-path>` overrides default Guest Path | PASS | Updated read-write folder to `/code` and read-only folder to `/reference`. |
| Existing host folder updates idempotently | PASS | Re-adding the same resolved host path changed its Guest Path to `/code` without duplicate entries. |
| Duplicate Guest Paths are rejected | PASS | Attempt to add another host folder at `/code` failed. |
| Overlapping host folders are rejected | PASS | Attempt to add `$RW_DIR/subdir` failed. |
| Symlink realpath validation prevents bypass | PASS | Symlink to `$RW_DIR/subdir` was rejected as an overlap. |
| Display paths are preserved while validation uses resolved paths | PASS | Human-facing list/spec kept the submitted host paths; symlink/overlap checks used real paths. |
| Read-write folders preserve Host-Safe File Ownership | PASS | Guest-created and guest-modified files in `/code` had host UID `501`. |
| Read-only folders are readable and reject writes from the Sandbox Guest | PASS | Write to `/reference/blocked.txt` failed with `Read-only file system`; no host file was created. |
| Config changes apply immediately when stopped | PASS | Folder add/remove commands recreated stopped backend runtime and subsequent start saw the mount changes. |
| Running config changes ask first | PASS | Piping `n` to a folder add while running showed `Apply changes to running Sandbox VM ...?` and left spec unchanged. |
| Acceptance demonstrated against real Apple backend | PASS | Harness used `.build/debug/sand` and `container`; no fake backend was used. |

## Deterministic test evidence

- `swift test` — 64 tests passing.
