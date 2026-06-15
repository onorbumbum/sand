# Working Directory Mapping Validation

Date: 2026-05-18 23:47 local

Conclusion: **PASS — `sand <name> run` and `sand <name> shell` start in the mapped Guest Path when the Host cwd is inside an Shared Folder, resolve symlinked Host cwd paths, and warn/fall back to `/workspace` outside Shared Folders.**

Raw evidence: `docs/validation/working-directory-mapping/run-20260518-234712.log`

Harness: `docs/validation/working-directory-mapping/validate.sh`

## Scenario

- Sandbox Name: `sand-wd-234712`
- Sandbox Image: `sand/developer-ready:ubuntu-lts`
- Resource Profile: 2 CPUs, 1GB memory
- Backend: Apple `container` CLI 0.12.3
- Host test root: `/tmp/sand-working-directory-sand-wd-234712`
- Shared Folder: host `.../project` mounted as `/workspace/project`

## Requirement results

| Requirement | Result | Evidence summary |
|---|---:|---|
| From inside an Shared Folder, `sand <name> run pwd` starts at mapped Guest Path | PASS | Host cwd `.../project` printed `/workspace/project`. |
| Nested Host Mac directories map to nested Guest Path | PASS | Host cwd `.../project/src/module` printed `/workspace/project/src/module`. |
| Symlinked Host Mac cwd paths map correctly using resolved real paths | PASS | Host cwd `.../project-link/src/module` printed `/workspace/project/src/module`. |
| Outside all Shared Folders emits a clear warning | PASS | stderr contained `Current directory is not inside an Shared Folder; starting in /workspace.` |
| Outside all Shared Folders commands start in `/workspace` or Sandbox User home | PASS | Outside Host cwd `run pwd` printed `/workspace`. |
| `sand <name> shell` uses same behavior as `run` | PASS | tmux-driven real shell opened at `/workspace/project/src/module` inside the Shared Folder and `/workspace` outside, with the same warning. |
| Working Directory Mapping behavior has deterministic tests independent of Apple `container` | PASS | `WorkingDirectoryMapperTests` plus lifecycle tests exercise mapping and warnings through fake backend. |
| Acceptance demonstrated against real Apple backend | PASS | Harness used `.build/debug/sand` and Apple `container`; no fake backend was used. |

## Deterministic test evidence

- `swift test` — 66 tests passing.
