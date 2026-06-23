---
title: Build a self-made macOS base from IPSW with explicit bootstrap
status: done
type: issue
category: enhancement
labels:
  - ready-for-agent
  - hitl
  - sand
  - sandbox-vm
  - macos
  - tart
  - install-flow
created: 2026-06-22
---

## Parent

- `issues/sand/prd-macos-sandbox-vm-tart-backend.md`

## What to build

Give the user a high-trust alternative to prebuilt registry images without locking Sand to one macOS release. Keep macOS sources open-ended:

- `sand create <name> --os macos --from <tart-oci-image-or-local-sandbox>` clones any Tart-compatible macOS image, e.g. Sequoia, Tahoe, Xcode, pinned digest, or local clean sandbox.
- `sand create <name> --os macos --from-ipsw <latest|path|url>` creates a self-built macOS VM via `tart create --from-ipsw`.
- `sand create <name> --os macos` with no source fails with a helpful source-selection message instead of silently choosing Sequoia or starting a long/manual IPSW flow.

The IPSW path is explicitly two-stage because raw IPSW installs require first-boot macOS setup before SSH/key automation is available. `create --from-ipsw` creates the VM, sets resources, records it as setup-required, and tells the user to run `sand <name> gui` to complete first boot. After the user creates/enables the Sandbox User, `sand bootstrap <name>` verifies SSH/passwordless sudo, injects the Sand key, performs backend configuration, and transitions the sandbox to the normal frictionless `shell`/`run` path.

Document the macOS Setup Checklist as optional one-time GUI work whose result persists in Guest State and Clones: create/configure the Sandbox User for raw IPSW, sign into Apple ID only if needed, install full Xcode, install simulator runtimes, and enable Xcode automatic signing only if wanted. This is never a per-build gate.

## Acceptance criteria

- [x] `sand create <name> --os macos --from-ipsw <latest|path|url>` runs the macOS Install Flow via `tart create --from-ipsw`.
- [x] `sand create <name> --os macos` with no source rejects with a helpful message showing `--from <image-or-local-sandbox>` and `--from-ipsw <latest|path|url>` choices.
- [x] macOS source selection is open-ended; Tahoe, Sequoia, pinned Tart OCI images, local sandboxes, and supported IPSWs are accepted without hardcoding one base image as product policy.
- [x] The IPSW create flow sets resources and records the sandbox as setup-required, not ready-for-shell.
- [x] The setup-required flow tells the user to run `sand <name> gui` and complete the first-boot Sandbox User setup before bootstrap.
- [x] `sand bootstrap <name>` verifies SSH reachability and passwordless sudo, injects the Sand SSH key, runs post-create backend configuration, and transitions the sandbox to ready.
- [x] After bootstrap, the self-built base is reachable via `sand <name> shell` with the same injected-key, zero-prompt session path as a cloned sandbox. (Setup-required sandboxes are gated out of `shell`/`run` until bootstrap flips them to ready; the post-bootstrap path is identical to a cloned sandbox. Real-Tart shell reachability is part of the HITL acceptance below.)
- [x] No third-party virtualization GUI app is required; the only dependency is the Tart CLI.
- [x] The macOS Setup Checklist is documented as a one-time `gui` step whose result persists in Guest State and Clones, not a per-build gate. (Captured in `sand create --help`/`sand bootstrap --help` and in this issue; the full narrative macOS-guest doc is the dedicated issue `030-document-macos-guests.md`.)
- [x] Deterministic tests assert Tart command intent, setup-required state, bootstrap state transition, and no-source helpful rejection.
- [x] Acceptance is demonstrated against real Tart on Apple Silicon.

## Definition of Done

- [x] Deterministic tests are added/updated and `swift test` passes.
- [x] Backend-dependent acceptance evidence uses real Tart, not a fake.
- [x] The install/bootstrap flow goes through `SandboxBackend`; no reimplementation of install in-process.
- [x] First-boot and Apple-ID-gated steps are documented, not falsely automated.

## Resolved defects & fix plan (real-Tart HITL — 2026-06-23)

The 2026-06-23 11:25 PDT HITL run on real Tart 2.32.1 / Apple Silicon got create-from-IPSW and first-boot working but uncovered **two real implementation defects** that the fake-backend deterministic tests cannot catch. Both defects are now fixed; this section keeps the root-cause record. Full command-by-command evidence is in the `2026-06-23 11:25 PDT` Progress entry below.

**Validation fixture:** the local `ipswbox` macOS VM was created from IPSW and first-booted. Its temporary credentials/IP lived in gitignored `.env.hitl` during validation. The fixture and `.env.hitl` were deleted after final acceptance.

### Decision (with Onur, 2026-06-23 ~11:30 PDT)

Key injection for the IPSW path moves to **SSH with a one-time password**, replacing `tart exec`.

- **Why:** a vanilla macOS VM installed from IPSW ships **no Tart guest agent**, so `tart exec` hangs indefinitely. Remote Login (SSH) is enabled during first-boot and is proven reachable. So the *injection mechanism* is the only problem.
- **Rejected alternatives:** (a) require installing `tart-guest-agent` at first-boot — adds a manual GUI/download step and keeps the guest-agent dependency; (b) SSH-primary with `tart exec` fallback for clones — more branching than warranted now.

### Defect 1 — `sand gui` uses guest Screen Sharing (`--vnc`), unusable before first-boot

`TartCLIBackend.gui` runs `tart run --vnc` then opens `vnc://admin@<ip>`. `--vnc` proxies the **guest's** Screen Sharing service, which isn't enabled until first-boot completes — the exact thing `gui` is needed for. Real error: *"Make sure Screen Sharing or Remote Management … is enabled on the remote computer. Connection failed to 192.168.65.4."*

- **Workaround used in the run:** `tart run --vnc-experimental <name>` (Tart's own built-in VNC server, no guest cooperation) printed `vnc://:<pw>@127.0.0.1:<port>` and auto-opened Screen Sharing; first-boot was completed through it.
- **Fix implemented:** for a `setup-required` spec, `gui` uses Tart's built-in VNC (`--vnc-experimental`) instead of `--vnc`. Ready/cloned VMs keep `--vnc` (guest Screen Sharing is up by then).

### Defect 2 (root blocker) — `sand bootstrap` injects the key via `tart exec`, which hangs on a raw IPSW VM

`TartCLIBackend.bootstrap` → `injectPublicKey` → `tart exec <name> /bin/zsh -lc <script>` (a *retrying* runner). On `ipswbox` each `tart exec` hung; the retry loop spawned exec after exec and never got past key injection. Standalone proof: `tart exec ipswbox /bin/zsh -lc 'echo hello-from-guest'` produced no output and was still running at 9 s+ (on a guest-agent VM it returns instantly). `bootstrap`'s `configureSharedFolderSymlinks` uses `tart exec` the same way and would also hang. SSH, by contrast, works: `ssh -o BatchMode=yes admin@192.168.65.4 true` → `Permission denied (publickey,password,keyboard-interactive)` (server reachable, key just not installed yet).

### Fix plan (TDD, 2 slices)

**Slice 1 — Bootstrap over SSH (root blocker, implemented).** In `TartCLIBackend`:
- Replace `injectPublicKey`'s `tart exec` with an SSH bootstrap path, reusing the existing authorized-keys append script with the pubkey embedded in the remote command. Password prompting is handled by the bootstrap password-SSH runner, and a key-auth probe makes reruns idempotent.
- Change `configureSharedFolderSymlinks` from `tart exec` to key-based `sshRunner.run(sshArguments(… remoteCommand: script))` (key is installed by then).
- Reorder `bootstrap` so `waitForIPAddress` runs *before* injection (SSH needs the IP; `tart exec` didn't). `waitForSSH`/`verifyPasswordlessSudo` already use key-based ssh — unchanged.
- **Tests:** assert `bootstrap` issues the ssh password-auth injection (not `tart exec`) with the authorized-keys script, and runs shared-folder config over ssh; assert ordering (IP before injection).

**Slice 2 — `gui` uses `--vnc-experimental` for setup-required VMs (Defect 1, implemented).**
- Branch `gui` on `bootstrapState`: `setup-required` → `tart run --vnc-experimental` (open the Tart-printed `vnc://…` URL; Tart also auto-opens Screen Sharing); `ready` → existing `--vnc` + `vnc://admin@<ip>` path.
- **Tests:** assert setup-required `gui` starts `--vnc-experimental`; ready path unchanged.

### Live validation

Final live validation passed; see **Final acceptance evidence** below.

### Out-of-scope note (follow-up candidate)

The clone/start path's `injectPublicKey` + signing also use `tart exec`. That's fine for Cirrus base images (they ship the guest agent), but a user who *clones a self-built IPSW base lacking the agent* would hit the same hang. Not in scope here; flag for a follow-up issue if the self-built-base clone path becomes a supported flow.

## Progress

### 2026-06-23 10:29 PDT — Not complete: Tart IPSW path has a headless-bootstrap gap

Checked the issue against the current Tart backend and real Tart CLI (`tart 2.32.1`). The implementation is not complete and should not be moved to `done` yet.

Findings:

- Current `sand create <name> --os macos` still generates a macOS spec with the default Linux image reference and the Tart backend attempts `tart clone`, not `tart create --from-ipsw`.
- Real Tart syntax is `tart create <name> --from-ipsw <path|latest>` / `tart create --from-ipsw=latest <name>`.
- Tart's own quick-start docs state that after `tart create --from-ipsw=latest <name>`, the user must manually complete the initial macOS setup, create the conventional `admin`/`admin` user, enable Remote Login, disable lock/screen saver, and configure passwordless sudo.
- `tart exec` requires Tart Guest Agent, and Tart docs say only non-vanilla Cirrus Labs VM images already include it. A raw IPSW-created VM is therefore not guaranteed to support the existing backend's post-create `tart exec` key-injection/configuration path.

Root blocker:

- The acceptance criteria require `sand create <name> --os macos` to build from IPSW, enable SSH, configure the Sandbox User, inject the key, and leave `sand <name> shell` zero-prompt reachable. Tart's documented IPSW flow includes irreducible manual first-boot/OOBE steps before SSH/agent automation is available, so this cannot honestly be completed as a fully headless create flow without a new bootstrap design.

Verification run before stopping:

- `swift package clean && swift test` — passed, 113 tests, 0 failures.
- `tart --version` — `2.32.1`.
- `tart create --help` confirms `--from-ipsw <path>` support.

Recommended next decision:

1. Either revise this issue to a truthful two-stage flow: `sand create --os macos` creates the IPSW VM and records/setup-guides the required first GUI boot, then a separate `sand bootstrap <name>` or `sand apply <name>` completes SSH/key configuration after the user creates/enables the Sandbox User.
2. Or require a prepared IPSW/installer automation mechanism that installs the user, SSH, passwordless sudo, and Tart Guest Agent before claiming zero-prompt shell acceptance.

### 2026-06-23 10:33 PDT — Product decision: explicit source + two-stage IPSW bootstrap

Decision recorded with Onur:

- Do not hardcode Sequoia as product policy. Sequoia can remain a known-good example; Tahoe, pinned Tart OCI images, local sandboxes, and supported IPSWs must be allowed.
- Do not make `sand create <name> --os macos` ambiguous. With no source, reject and show choices.
- Use `--from <image-or-local-sandbox>` for fast clone paths.
- Use `--from-ipsw <latest|path|url>` for self-built macOS.
- Treat raw IPSW as setup-required until the user completes first-boot GUI setup and runs `sand bootstrap <name>`.

### 2026-06-23 10:49 PDT — Two-stage IPSW flow implemented and deterministically tested (HITL real-Tart acceptance pending)

Implemented the explicit-source + two-stage IPSW bootstrap flow agreed in the 10:33 decision, via TDD (4 slices, RED→GREEN per slice). `swift test`: 124 tests, 0 failures (was 113). State model: `bootstrap` field on the spec (Onur approved), rendered only when `setup-required` so ready specs stay byte-stable.

Slices:

- **Slice 1 — CLI surface.** `create` now parses `--from-ipsw <latest|path|url>` (implies `--os macos`, sets `CreateRequest.ipswSource`, image `ipsw:<source>`), rejects `--from` + `--from-ipsw` together (`conflictingOptions`), and rejects `--os macos` with no source via `CLICommandError.macOSSourceRequired` naming both `--from <image-or-local-sandbox>` and `--from-ipsw <latest|path|url>`. Updated `create` help.
- **Slice 2 — setup-required create.** `SandboxSpec.bootstrapState: BootstrapState (.ready|.setupRequired)` with YAML render/parse. `TartCLIBackend.provisionFromIPSW` runs `tart create <name> --from-ipsw <src>` + `tart set` resources/disk only — no clone, no start, no key injection. `LifecycleCoordinator.createFromIPSW` records the spec as setup-required and prints the GUI-then-bootstrap guidance.
- **Slice 3 — `sand bootstrap <name>`.** New command/protocol method. `TartCLIBackend.bootstrap` injects the Sand key (`tart exec`), then verifies SSH reachability and passwordless sudo (`ssh … true` / `ssh … sudo -n true`) with the injected key, runs shared-folder config, and stops. `LifecycleCoordinator.bootstrap` guards macOS + setup-required, transitions to `.ready`. `shell`/`run` are gated with `SandboxBootstrapError.setupRequired` until bootstrap completes; gui stays available so the user can finish first boot.
- **Slice 4 — docs/help.** Help for `create`/`bootstrap`/top-level documents the one-time first-boot Setup Checklist (one-time `gui`, not a per-build gate). Generated `docs/cli-reference.md` was intentionally not hand-edited; extending the doc generator with a `bootstrap` section + the macOS-guest narrative is the dedicated issue `030-document-macos-guests.md`.

Design notes / honest caveats:

- Key injection in `bootstrap` uses `tart exec` (Tart Guest Agent), consistent with the existing clone path's `injectPublicKey`/signing. Raw IPSW VMs are not guaranteed to ship the guest agent (per the 10:29 finding); this is the same assumption the existing macOS backend already makes and is exactly what the real-Tart HITL acceptance must confirm.
- Did **not** mark this issue done or commit: the issue is `hitl`-labelled and its real-Tart acceptance + DoD evidence item require a human-driven IPSW install (~20 min) and interactive macOS first-boot (create admin user, enable Remote Login, passwordless sudo) that cannot be demonstrated headlessly. Implementation + deterministic tests are complete and left in the working tree for that acceptance run.

Verification before stopping: `swift test` — 124 tests, 0 failures. `swift run sand create --help`, `sand bootstrap --help`, and `sand create macbox --os macos` (no-source rejection) render as expected.

### 2026-06-23 10:57 PDT — Re-verified; only HITL real-Tart acceptance remains (not done)

Re-checked the working tree under TDD. No deterministic slice is left to write — every testable behavior in the acceptance criteria and DoD is implemented and green. The two unchecked boxes (criterion "demonstrated against real Tart on Apple Silicon" and DoD "backend-dependent acceptance evidence uses real Tart") are irreducibly human-in-the-loop: they need Onur to drive a ~20–40 min real-Tart IPSW install plus an interactive macOS first-boot (create `admin` user, enable Remote Login, passwordless sudo) that cannot be demonstrated headlessly.

Verification before stopping:

- `swift test` — 124 tests, 0 failures.
- Implementation + deterministic tests remain uncommitted in the working tree, ready for the HITL acceptance run documented below.

Not moved to `issues/done` and not committed: the issue is `hitl`-labelled and stays open until the real-Tart acceptance runbook is driven with Onur. Next action is the runbook below, not more headless TDD.

### 2026-06-23 11:25 PDT — HITL real-Tart run: install + first-boot OK, **bootstrap blocked by missing guest agent** (two real defects found)

Drove the runbook with Onur on real Tart 2.32.1 / Apple Silicon. Steps 0–2 passed; Step 3 (bootstrap) is blocked by a guest-agent dependency. Two genuine implementation defects surfaced that deterministic tests (fake backend) could not catch. **Acceptance boxes remain unchecked.** VM left running for the fix; not deleted.

**What passed:**

- **Step 1 — create from IPSW.** `swift run sand create ipswbox --os macos --from-ipsw latest` downloaded `latest` and ran `tart create … --from-ipsw` + `tart set` (~20 min; IPSW ~16 GB, disk restored to ~20 GB actual of a 64 GB sparse image). Printed the setup-required guidance block. Exit 0.
- **Checkpoints (criteria 1, 4, 5).** `tart list` shows `ipswbox … stopped`; `sand spec ipswbox` → `os: macos` + `bootstrap: setup-required`; `sand status ipswbox` → `image: ipsw:latest`, 4 CPU/16 GB/64 GB.
- **Negative gate (criterion 7).** `sand shell ipswbox` refused in **0.5 s** (no SSH hang): "still needs first-boot setup … run `sand bootstrap ipswbox`."

**Defect 1 — `sand gui` uses guest Screen Sharing (`--vnc`), which a fresh IPSW VM cannot serve.**

- `TartCLIBackend.gui` runs `tart run --vnc` then opens host Screen Sharing at `vnc://admin@<ip>`. `--vnc` proxies the **guest's** Screen Sharing service, which is not enabled until first-boot is complete — the exact thing `gui` is needed *for*. Real error to Onur: *"Make sure Screen Sharing or Remote Management … is enabled on the remote computer. Connection failed to 192.168.65.4."*
- **Workaround used to unblock first-boot:** `tart run --vnc-experimental ipswbox` (Tart's **own** built-in VNC server, no guest cooperation) → printed `vnc://:<pw>@127.0.0.1:<port>` and auto-opened Screen Sharing. Onur completed Setup Assistant (account `admin`), enabled Remote Login, and configured passwordless sudo.
- **Fix needed:** for setup-required VMs, `gui` must use `--vnc-experimental` (or Tart's native windowed `tart run`), not `--vnc`.

**Defect 2 (root blocker) — `bootstrap` injects the key via `tart exec`, but a vanilla IPSW VM has no Tart guest agent, so `tart exec` hangs forever.**

- `TartCLIBackend.bootstrap` → `injectPublicKey` → `tart exec <name> /bin/zsh -lc <script>` (a *retrying* runner). On `ipswbox` each `tart exec` hung indefinitely; the retry loop spawned exec after exec and never progressed past key injection. Standalone confirmation: `tart exec ipswbox /bin/zsh -lc 'echo hello-from-guest'` produced **no output, still running at 9 s+** (on a guest-agent VM this returns instantly). Vanilla macOS from IPSW does not ship `tart-guest-agent`.
- **SSH itself works.** `ssh -o BatchMode=yes admin@192.168.65.4 true` → `Permission denied (publickey,password,keyboard-interactive)`. Remote Login is up, server reachable, key simply not installed yet. So the frictionless path is viable — the *injection mechanism* is the problem, not SSH.
- **Implication:** the current `tart exec`-based bootstrap (and the clone path's `injectPublicKey`/signing, which make the same assumption) cannot configure a raw IPSW VM. Key injection for the IPSW path must move to **SSH** (e.g. one-time password auth to append the Sand key to `~/.ssh/authorized_keys`), or first-boot must include installing the Tart guest agent. **Decision pending with Onur — not worked around silently.**

**State for the fix run:** `ipswbox` is created + first-boot-complete (account `admin`, Remote Login on, passwordless sudo set) and currently **running** at `192.168.65.4` (held by a `tart run --vnc-experimental`). This is a ready-made fixture to validate an SSH-based injection path without redoing the ~20 min install. Spec is still `bootstrap: setup-required`. Clean up later with `sand delete ipswbox --force`.

### 2026-06-23 11:32 PDT — Decision recorded; fix design documented; implementation deferred by Onur

Reviewed the two defects with Onur. Decision: key injection moves to **SSH with a one-time password** (not guest-agent install). Onur chose to **document thoroughly now and defer the code change**, so no slices were written this turn.

- Added the **"Open defects & fix plan (real-Tart HITL — 2026-06-23)"** section above (decision + both defects + the 2-slice TDD plan + live-validation steps).
- Annotated the two affected acceptance criteria with ⚠️ pointers to that section.
- Stashed the `ipswbox` first-boot password and IP in **`.env.hitl`** (added `.env` / `.env.*` to `.gitignore`; verified the file is not tracked). The password is intentionally **not** written into this issue.
- The `ipswbox` fixture VM is left in place for the eventual SSH-bootstrap validation. The two HITL acceptance/DoD boxes remain unchecked.

## Final acceptance evidence

### 2026-06-23 12:08 PDT — Live IPSW acceptance passed; fixture cleaned up

Completed the remaining real-Tart acceptance on Apple Silicon with Tart `2.32.1` and the existing `ipswbox` fixture created from `--from-ipsw latest`.

Fixes validated:

- `sand ipswbox gui` for a setup-required VM now uses Tart built-in VNC (`--vnc-experimental`), avoiding guest Screen Sharing before first boot.
- `sand bootstrap ipswbox` no longer depends on `tart exec`/Tart Guest Agent for raw IPSW VMs. It injects the Sand SSH key through the SSH bootstrap path, then verifies key-based SSH and passwordless sudo.
- During validation, passwordless sudo was corrected in the guest, then bootstrap completed successfully and flipped the spec to ready.

Evidence:

- `swift run sand bootstrap ipswbox` → `Bootstrapped macOS Sandbox VM 'ipswbox'. It is ready — use `sand ipswbox shell`.` Exit 0.
- `swift run sand spec ipswbox` after bootstrap had no `bootstrap:` line.
- `swift run sand run ipswbox echo ok` → `ok`, exit 0.
- `swift run sand shell ipswbox`, then `echo shell-ok; exit` → `shell-ok`, exit 0, no password prompt.
- `make check` — passed: 126 tests, 0 failures; Documentation Freshness Gate passed.
- Cleanup completed: `swift run sand delete ipswbox --force` exit 0; `.env.hitl` removed; `tart list` no longer shows `ipswbox`.

## Blocked by

- `issues/sand/023-clone-and-shell-macos-sandbox.md` (done)
