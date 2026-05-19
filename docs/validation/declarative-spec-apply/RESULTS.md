# Declarative Spec Apply Validation

Date: 2026-05-18 23:57 local

Conclusion: **PASS — `sand create --from spec.yaml` creates a real Sandbox VM from a user-authored spec, `sand apply <name>` reconciles manual spec edits against Apple `container`, running applies prompt before interruption, Guest State survives runtime recreation, and post-create CPU edits are rejected.**

Raw evidence: `docs/validation/declarative-spec-apply/run-20260518-235756.log`

Harness: `docs/validation/declarative-spec-apply/validate.sh`

## Scenario

- Sandbox Name: `sand-apply-235756`
- Sandbox Image: `sand/developer-ready:ubuntu-lts`
- Resource Profile: 2 CPUs, 1GB memory
- Backend: Apple `container` CLI 0.12.3
- Host test root: `/tmp/sand-declarative-apply-sand-apply-235756`
- Initial Allowed Folder: host `.../code` mounted as `/code`
- Manual spec edits added `.../extra` as `/extra` and `.../running` as `/running`

## Requirement results

| Requirement | Result | Evidence summary |
|---|---:|---|
| `sand create --from spec.yaml` creates from a user-authored spec | PASS | CLI command omitted an explicit name; `sand` inferred `sand-apply-235756` from the spec and created real host metadata/runtime. |
| `sand apply <name>` reconciles manual Sandbox Spec edits | PASS | Manual spec edit adding `/extra` was applied; guest read `/extra/extra.txt`. |
| Apply changes real backend configuration, not only Host Metadata | PASS | Guest-visible mount changed after `sand apply`; this was verified inside the real Apple backend. |
| Runtime recreation remains hidden/internal | PASS | User-facing flow used only `sand apply`; no runtime recreation command was exposed. |
| Guest State survives apply flows requiring runtime recreation | PASS | Marker written to `/state/apply-marker` before apply was readable after stopped and running apply recreations. |
| CPU edits after creation are rejected | PASS | Manual `resources.cpus: 4` edit failed with `resource profile field cannot be edited after creation: cpus`. |
| Stopped configuration changes apply immediately | PASS | Stopped apply exposed `/extra` without requiring manual start/stop lifecycle commands. |
| Running configuration changes ask first | PASS | Running apply prompted; `n` cancelled without exposing `/running`; `y` applied and exposed `/running`. |
| Lifecycle Mutation serialization | PASS | Deterministic lifecycle tests cover apply/create/delete/start/stop lifecycle locks. |
| Acceptance demonstrated against real Apple backend | PASS | Harness used `.build/debug/sand` and Apple `container`; no fake backend was used. |

## Deterministic test evidence

- `swift test` — 72 tests passing.
