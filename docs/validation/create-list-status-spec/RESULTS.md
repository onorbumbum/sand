# Create/List/Status/Spec Validation

Date: 2026-05-18 22:53 local

Conclusion: **PASS — `sand create`, `sand list`, `sand <name> status`, and `sand <name> spec` work against the real Apple backend for a stopped Sandbox VM with no Allowed Folders.**

Raw evidence: `docs/validation/create-list-status-spec/run-20260518-225306.log`

## Scenario

- Sandbox Name: `sand-tdd-225306`
- Sandbox Image: `sand/developer-ready:ubuntu-lts`
- Resource Profile: 2 CPUs, 1024MB requested; active spec renders `1GB`
- Allowed Folders: none
- Backend: Apple `container` CLI

## Requirement results

| Requirement | Result | Evidence summary |
|---|---:|---|
| `sand create <name>` creates Host Metadata under `~/.sand/` | PASS | `sand <name> spec` printed the active persisted Sandbox Spec. |
| Create provisions real backend resources / Guest State | PASS | `sand list` and `sand <name> status` observed the backend-created sandbox before cleanup. |
| Create leaves Sandbox VM stopped | PASS | `sand list` and `sand <name> status` both reported `stopped`. |
| `--cpus`, `--memory`, and `--image` work at create time | PASS | Status/spec showed 2 CPUs, 1GB memory, and `sand/developer-ready:ubuntu-lts`. |
| A Sandbox VM can be created with no Allowed Folders | PASS | Status/spec showed `allowedFolders: 0` / `allowedFolders: []`. |
| `sand list` shows concise Sandbox Status | PASS | Output: `sand-tdd-225306 stopped sand/developer-ready:ubuntu-lts 0 folders` (tab-separated). |
| `sand <name> status` shows useful config/backend status | PASS | Output included name, state, image, resources, and Allowed Folder count; no raw backend JSON. |
| `sand <name> spec` prints active Sandbox Spec | PASS | Output matched the active YAML spec. |

Cleanup also passed: `sand delete <name> --force` exited 0, `container inspect <name>` returned `[]`, and the spec file no longer existed under `~/.sand/specs/`.

No fake or in-memory backend was used for acceptance evidence.
