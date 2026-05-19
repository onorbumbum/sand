# Pi Workload Credential Boundary Validation

Date: 2026-05-19 00:20 local

Conclusion: **PASS — Pi runs as an ordinary opaque Workload Command in a real Sandbox Guest, Pi identity resolves to Guest State, Guest Secrets are sandbox-local, and host Pi/credential/secret-forwarding surfaces are absent by default.**

Raw evidence: `docs/validation/pi-workload-credential-boundary/run-20260519-002050.log`

## Scenario

- Sandbox Name: `sand-pi-boundary-002050`
- Sandbox Image: `sand/developer-ready:ubuntu-lts`
- Resource Profile: 2 CPUs, 1GB memory
- Backend: Apple `container` CLI via `.build/debug/sand`

## Requirement results

| Requirement | Result | Evidence summary |
|---|---:|---|
| `sand <name> run pi [args...]` works as a normal Workload Command | PASS | `.build/debug/sand sand-pi-boundary-002050 run pi --version` exited 0 and printed `0.73.1`. |
| `sand` does not parse or understand Pi-specific flags | PASS | Existing deterministic CLI tests pass Pi args through unchanged; live validation invokes Pi only through generic `run`. |
| No Pi-specific `sand <name> pi` shortcut in v1 | PASS | `.build/debug/sand "$NAME" pi` failed with `unsupported sandbox action: pi`. |
| Host Mac `~/.pi` is not mounted by default | PASS | Spec had `allowedFolders: []`; backend inspection did not expose `/Users/`; guest command verified `/Users` and `/host` are absent. |
| Host credential files are not mounted or forwarded by default | PASS | Guest command verified no `$HOME/.aws`, `$HOME/.config/gcloud`, `$HOME/.ssh`, `/run/host-services/ssh-auth.sock`, or `SSH_AUTH_SOCK`; backend inspection rejected `/Users/`, `.aws`, `.config/gcloud`, `SSH_AUTH_SOCK`, and `/run/host-services`. |
| Pi Identity lives in Guest State | PASS | Guest command verified `$HOME/.pi -> /state/sandbox/.pi`, wrote `PI_IDENTITY_MARKER`, then `sand apply` recreated the runtime and the marker persisted. |
| Guest Secrets are sandbox-local in v1 | PASS | Guest command verified `$HOME/.sand-secrets -> /state/sandbox/secrets`; no host secret-forwarding socket/env was present. |
| No skill-source or Pi skill syncing behavior in `sand` v1 | PASS | No skill-source commands/options were used; command surface remains generic `run`. |
| Acceptance distinguishes unauthenticated smoke from human-authenticated setup | PASS | Log includes `UNAUTHENTICATED_PI_SMOKE=pi --version only; no human-authenticated Pi login or provider credential setup was attempted.` |
| Acceptance demonstrated against real Apple backend | PASS | Validation built the Swift CLI, built the developer-ready image with Apple `container build`, created a real sandbox, ran real guest commands, used `container inspect`, and deleted the sandbox. |

## Deterministic test evidence

- `swift test` — 77 tests passing.

## Exact command

```bash
docs/validation/pi-workload-credential-boundary/validate.sh
```
