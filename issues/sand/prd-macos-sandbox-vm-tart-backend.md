---
title: Add macOS Sandbox VM support via a Tart CLI backend
status: ready-for-agent
type: prd
category: enhancement
labels:
  - ready-for-agent
  - sand
  - sandbox-vm
  - macos
  - tart
  - backend
created: 2026-06-22
---

## Problem Statement

The user can run isolated **Sandbox VMs** today, but only Linux ones (Apple `container` backend). Xcode/iOS work — the kind that genuinely benefits from an isolated, disposable, broadly-privileged environment — has no home in `sand`. The user needs to know whether macOS guests are even *feasible* under the existing architecture, and if so, wants the same product mental model ("a small computer I can `sand <name> shell` into, with explicit Shared Folders and Host-Safe File Ownership") extended to macOS guests, without the Linux experience regressing and without `sand` having to be code-signed or carry a virtualization entitlement.

The hard, previously-unanswered questions are: does file ownership survive across the host/guest boundary on macOS; can sessions be frictionless (no password prompt) against prebuilt images that ship known credentials; where do shared folders actually appear inside a macOS guest; and how do the spec and backend selection evolve to carry a second guest OS without breaking existing Linux specs.

## Solution

Add a second **Sandbox Backend** — a **Tart CLI backend** — behind the existing deep `SandboxBackend` protocol, so macOS **Sandbox VMs** are first-class alongside Linux ones. The guest OS becomes a create-time, immutable property of the **Sandbox Spec** (`os: linux|macos`, default `linux`). `sand` shells out to `tart` for macOS exactly as it shells out to `container` for Linux: pull/clone an OCI image and run it with sand-controlled mounts. See `docs/adr/0001-split-backends-linux-container-macos-tart.md`.

From the user's perspective:

- `sand create <name> --os macos --from <registry-image>` clones a prebuilt image (e.g. a Cirrus Xcode image) in seconds; `--os macos` alone runs the self-built **macOS Install Flow** (`tart create --from-ipsw`, ~30 min).
- `sand <name> shell` / `run` work identically to Linux — frictionless, no password prompt — over hidden SSH, using a per-sandbox SSH key `sand` generates and injects at create.
- `sand <name> gui` opens a **GUI Session** (Tart VNC + host Screen Sharing) for the Apple-ID-gated work no tool can automate.
- **Shared Folders** behave the same: the chosen **Guest Path** is preserved even though macOS virtiofs mounts at a fixed `/Volumes/My Shared Files/<tag>` location, via a backend-managed guest-side symlink. **Host-Safe File Ownership** holds for free because virtiofs writes land as the host user.
- **Outbound-Only Networking** holds: Tart's NAT keeps SSH/VNC reachable from the Host Mac only, never the LAN.
- macOS-only **Disk Size** (`disk:`) is a create-time, grow-only spec field.

Feasibility is gated on a mandatory **Tart Backend Validation Spike** on real Apple Silicon, run top-down by kill-probability, before the full backend is built — mirroring the Apple-container spike that preceded the Linux backend.

## User Stories

1. As the user, I want to create a macOS **Sandbox VM**, so that I can run Xcode/iOS workloads in isolation from my Host Mac.
2. As the user, I want macOS guests to be additive, so that my existing Linux sandboxes and workflows are unchanged.
3. As the user, I want the guest OS chosen at create time with `--os macos`, so that one flag selects the whole backend.
4. As the user, I want `linux` to remain the default guest OS, so that existing habits and specs keep working.
5. As the user, I want the guest OS to be immutable after create, so that a sandbox's backend identity is stable.
6. As the user, I want `sand create <name> --os macos --from <registry-image>` to clone a prebuilt image in seconds, so that I can start Xcode work without a 30-minute install.
7. As the user, I want `sand create <name> --os macos` (no `--from`) to run the self-built install-from-IPSW flow, so that I can build my own base when I need to.
8. As the user, I want a macOS **Clone** to copy-on-write from an existing clean sandbox or a registry image, so that new macOS sandboxes are cheap.
9. As the user, I want `sand <name> shell` on a macOS sandbox to open an interactive session with no username/password prompt, so that entering it feels the same as a Linux sandbox.
10. As the user, I want `sand <name> run <cmd>` to execute an opaque **Workload Command** on a macOS guest, so that the run model is identical across backends.
11. As the user, I want `sand` to generate and inject a per-sandbox SSH key at create, so that sessions are frictionless without relying on a shared default password.
12. As the user, I want the private key stored in **Host Metadata** under `~/.sand/`, so that only my host can reach the guest.
13. As the user, I want the baked-in image password kept only as documented break-glass for `gui`, so that the default credential is not my daily path.
14. As the user, I want `sand <name> gui` to open a **GUI Session** via Tart VNC and host Screen Sharing, so that I can do Apple-ID-gated setup that cannot be automated.
15. As the user, I want `gui` to be macOS-only, so that the command surface stays honest about what each guest supports.
16. As the user, I want **Shared Folders** on macOS to appear at the same chosen **Guest Path** as on Linux, so that my mental model and `--as` overrides are backend-agnostic.
17. As the user, I want the fixed `/Volumes/My Shared Files/<tag>` virtiofs location hidden behind a backend-managed symlink, so that I never have to think about it.
18. As the user, I want **Working Directory Mapping** to work on macOS, so that running from a mounted project drops me in the corresponding guest path.
19. As the user, I want files I create through a read-write Shared Folder on macOS to remain owned and editable by my host user without sudo, so that **Host-Safe File Ownership** holds.
20. As the user, I want read-only Shared Folders on macOS to actually block guest writes, so that **Access Mode** is real.
21. As the user, I want **Outbound-Only Networking** on macOS, so that the guest reaches the internet but no other machine on the LAN can reach the guest.
22. As the user, I want SSH and VNC bound host-only via Tart's NAT, so that the isolation guarantee is the same as Linux.
23. As the user, I want a macOS-only **Disk Size** field set at create, so that I can size a VM for Xcode.
24. As the user, I want Disk Size to be grow-only on clone and never an in-place resize, so that the constraint matches APFS reality.
25. As the user, I want macOS resource defaults of 4 CPU / 16GB, so that Xcode builds have room.
26. As the user, I want CPU and memory to stay immutable after create, so that lifecycle complexity stays low across both backends.
27. As the user, I want existing Linux **Sandbox Specs** (with no `os` field) to keep parsing unchanged, so that the schema change is invisible to me.
28. As the user, I want `os: macos` plus `disk:` to be accepted in a spec, so that I can author macOS sandboxes declaratively.
29. As the user, I want `disk:` rejected on a Linux spec, so that the spec reflects real per-backend capability.
30. As the user, I want `sand apply` on macOS to update/restart without touching the disk, so that config changes do not risk Guest State.
31. As the user, I want CPU/memory and image changes rejected by apply on macOS too, so that immutability is uniform.
32. As the user, I want `sand list` and `sand <name> status` to show macOS sandboxes with their guest OS, so that I can tell my sandboxes apart.
33. As the user, I want `sand <name> logs` to surface macOS backend failures, so that a failed clone or start is debuggable.
34. As the user, I want `sand doctor` to check for the `tart` CLI and version, so that I learn about a missing dependency before I try to create a macOS sandbox.
35. As the user, I want `sand doctor` to only require `tart` when relevant, so that a Linux-only user is not nagged about Tart.
36. As the user, I want a clear error if I `--os macos` without `tart` installed, so that the fix (`brew install cirruslabs/cli/tart`) is obvious.
37. As the user, I want `sand delete` on a macOS sandbox to remove the VM and its Host Metadata (including the injected key), so that deletion is complete.
38. As the user, I want start/stop on macOS to preserve **Guest State** (the whole VM disk), so that stop/start behaves like powering a Mac off and on.
39. As the user, I want to understand that macOS guests are capped (~2 concurrent per Apple's license) and heavy (~100GB each), so that I plan for "a handful," not "dozens."
40. As the user, I want `sand` to stay unsigned and entitlement-free, so that installation remains a plain CLI dependency.
41. As the maintainer, I want a second `SandboxBackend` implementor, so that macOS support does not leak backend details into the CLI or spec layers.
42. As the maintainer, I want a `BackendResolver` injected into `LifecycleCoordinator`, so that the coordinator picks a backend from the spec's guest OS instead of binding to one backend.
43. As the maintainer, I want the resolver to be the single place guest-OS-to-backend mapping lives, so that adding future backends is localized.
44. As the maintainer, I want the Tart backend command construction unit-tested without a live VM, so that backend intent is verified deterministically.
45. As the maintainer, I want Tart error translation tested with stderr fixtures, so that user-facing errors are stable.
46. As the maintainer, I want the architecture boundary test extended to forbid `tart` strings outside the backend, so that the deep-module boundary is enforced.
47. As the maintainer, I want a mandatory **Tart Backend Validation Spike** before building the backend, so that feasibility is proven on hardware, not assumed.
48. As the maintainer, I want the spike ordered by kill-probability with explicit stop conditions, so that a hard failure stops work early per ADR-0001.
49. As the maintainer, I want the spike to prove the Guest Path symlink survives a real Xcode build (DerivedData resolves), so that the riskiest "should work" item is retired.
50. As the maintainer, I want the in-process Virtualization Framework to remain the only documented fallback if Tart fails a hard requirement, so that we never silently adopt a non-Apple backend.
51. As the maintainer, I want prebuilt Cirrus images pinned by digest, so that the supply chain for the default macOS base is reproducible.
52. As the maintainer, I want the self-built IPSW + Apple-ID path kept off the feasibility critical path, so that irreducibly-manual steps do not drag down the verdict.
53. As the user, I want to build and run iOS apps in the Simulator on a macOS sandbox with no signing or Apple ID, so that the common dev loop has zero credential friction.
54. As the user, I want to code-sign builds for distribution (TestFlight/App Store/ad-hoc/enterprise) inside the sandbox by injecting my certificate and provisioning profile, so that CI-style signing works headlessly without an interactive Apple-ID login.
55. As the user, I want injected **Signing Credentials** treated as a **Guest Secret** in the keychain, so that my signing identity is not mounted from or shared with the Host Mac.
56. As the user, I want Apple-ID login for automatic signing to be an optional one-time GUI step that persists into Guest State and Clones, so that it is never a per-build gate.
57. As the user, I want it documented that physical-device deploy/debug is unsupported because Apple's Virtualization Framework has no USB passthrough for macOS guests, so that I do not expect `gui` to forward a host-connected iPhone.

## Implementation Decisions

- **Split backends, symmetric shape.** macOS uses a new `TartCLIBackend` implementing the existing `SandboxBackend` protocol; Linux keeps `AppleContainerCLIBackend`. Both shell out to a CLI that pulls/clones an OCI image and runs it with sand-controlled mounts. Per ADR-0001.
- **Backend selection seam.** Introduce a `BackendResolver` abstraction injected into `LifecycleCoordinator`, replacing the single hardcoded backend in `main.swift`. The resolver maps a spec's guest OS to the correct `SandboxBackend`. The coordinator remains backend-agnostic and is exercised in tests with a fake resolver/fake backends.
- **Spec schema is additive, no `schemaVersion` bump.** A `schemaVersion` bump is reserved for breaking changes; adding a guest OS and disk size is additive. The parser learns:
  - `os: linux|macos`, defaulting to `linux` so all existing specs remain valid.
  - `disk: <size>`, macOS-only.
  The parser currently throws `unsupportedField` on any unknown top-level key, so both keys must be taught explicitly.
- **Three new validation rules**, mirroring the existing `resources` immutability gates in `validateUpdate`:
  1. `disk` is rejected when `os != macos`.
  2. `os` is immutable after create (joins the image/cpu/memory immutable set).
  3. `disk` is grow-only on clone; in-place resize is rejected.
- **Guest Path is backend-aware but user-identical.** On macOS, the backend mounts via virtiofs at the OS-fixed `/Volumes/My Shared Files/<tag>` and creates a guest-side symlink from the chosen/derived Guest Path to it. The fixed location is a hidden backend detail; `--as` and Working Directory Mapping behave identically across backends.
- **Host-Safe File Ownership comes free on macOS.** virtiofs (Virtualization.framework) creates guest-written files on the host owned by the user who launched the VM — no uid translation, unlike Linux. Confirmed cheaply in the spike rather than engineered.
- **Frictionless sessions via injected key.** At create/clone, `sand` generates a per-sandbox SSH keypair, injects the public key into the macOS guest's `authorized_keys`, and stores the private key in Host Metadata under `~/.sand/`. All sand sessions use the key; the baked-in `admin`/`admin` password is documented break-glass for `gui` only.
- **Transport.** Hidden SSH (`tart ip` + ssh) for `shell`/`run`; `sand <name> gui` runs `tart run --vnc` and opens host Screen Sharing.
- **Apply semantics on macOS.** Shared-folder changes trigger stop/update/restart with the disk untouched (Guest State preserved). CPU, memory, and image changes are rejected by apply, as on Linux.
- **Doctor is os-aware.** Adds a `tart` presence/version check, required only for macOS operations; Linux-only users are not blocked by a missing Tart. Creating `--os macos` without `tart` fails with an actionable message.
- **Resource defaults are guest-OS-dependent.** Linux 4 CPU / 8GB; macOS 4 CPU / 16GB. Disk Size defaults to ~100GB on macOS.
- **No signing, no entitlement.** Tart carries the virtualization entitlement; `sand` only requires `tart` on PATH — a CLI peer to the `container` dependency.
- **Default macOS base is a pinned prebuilt Cirrus image**, with self-build via the macOS Install Flow as the high-trust alternative. The self-built IPSW + Apple-ID path stays off the feasibility critical path.
- **Distribution signing is in scope and headless.** Inject the developer's certificate (`.p12`) + provisioning profile into the guest keychain as a **Signing Credentials** Guest Secret (same shape as the SSH-key injection decision); `xcodebuild` signs without any interactive Apple-ID login. Apple-ID login is only for *automatic* signing management — an optional one-time `gui` step that persists into Guest State and Clones. Physical-device deploy is out of scope (no VF USB passthrough).
- **Known platform constraints, documented not hidden:** Apple's ~2-concurrent-macOS-VM license cap, and ~100GB / slower-boot per macOS VM.

## Testing Decisions

- **What makes a good test here:** assert external behavior and stable contracts — the `tart` argv that a given domain intent produces, the user-facing error a given backend failure maps to, whether a spec round-trips and which mutations are rejected — never private internals. Hardware-dependent guarantees are not certified by mocks.
- **Highest seam, reused:** `SandboxBackend` protocol. macOS lifecycle behavior (create/apply/start/stop/run/shell/delete, auto-start, prompts, mutation serialization) is tested through `LifecycleCoordinator` with the existing `RecordingSandboxBackend` fake plus a fake `BackendResolver` — no live VM. Prior art: `LifecycleCoordinatorTests`.
- **Backend selection:** test that `LifecycleCoordinator` resolves the backend from a spec's guest OS via the fake resolver, and that Linux specs resolve to the container backend.
- **Spec model:** extend `SandboxSpecTests` for `os` default/parse, `macos` + `disk` parse, rejection of `disk` on Linux, `os` immutability after create, and `disk` grow-only/no-in-place-resize. Prior art: existing `validateUpdate` immutability tests.
- **Tart backend command construction:** unit-test the argv for clone, run-with-`--dir` (rw/ro), key injection, and the `/Volumes` symlink — asserting domain intent, not scattering raw commands through CLI tests. Prior art: `AppleContainerCLIBackendDoctorTests` and the Apple-container backend command tests.
- **Tart error translation:** fixture-driven, with `tart` stderr samples under `Tests/SandCoreTests/Fixtures/`. Prior art: `BackendErrorTranslationTests` + `Fixtures/apple-container/`.
- **Doctor:** extend `DoctorChecksTests` for `tart` presence/version and os-relevance (Linux-only users not blocked).
- **Architecture boundary:** extend `ArchitectureBoundaryTests` to assert no `tart` strings appear outside the Tart backend module.
- **Guest Path symlink** is verified at the Tart backend command-construction level (the symlink command is emitted), not in `FolderPolicy`, which stays backend-agnostic.
- **Live/manual seam — the Tart Backend Validation Spike**, recorded under `docs/validation/` like the Apple-container spike, run top-down by kill-probability with stop conditions:
  1. Frictionless non-interactive session: clone → key injected → `shell` connects with zero prompt. *(stop if fails)*
  2. Guest Path symlink survives Xcode: real project opens/builds, DerivedData resolves, behind the `/Volumes` symlink. *(riskiest "should work")*
  3. Host-Safe File Ownership: guest write → host `ls -l` shows host user, editable without sudo. *(expected pass)*
  4. rw/ro mounts honored: read-only blocks writes.
  5. Host-only networking: `tart ip` SSH reachable from host, not from another LAN machine.
  6. Resource defaults sane: 4 CPU / 16GB completes a real Xcode build acceptably.
  7. 2-VM cap confirmed: empirically find where the Nth macOS VM fails to boot; document the number.

## Out of Scope

- **Physical-device deploy/debug** (running on a USB-connected iPhone/iPad): impossible because Apple's Virtualization Framework provides no USB passthrough for macOS guests — a platform limit, not a Tart/`sand` choice. `gui` gives VM desktop access, not host-device forwarding. (Distribution signing itself is *in scope* via injected **Signing Credentials**.)
- Interactive Apple-ID login as a gating requirement; it is an optional one-time GUI step for automatic signing only, and persists into Guest State and Clones.
- Inbound networking, port publishing, or LAN exposure for macOS guests (same as Linux v1).
- In-place disk resize, or post-create CPU/memory/os/image changes.
- A Pi-specific shortcut command; Pi on macOS runs as a normal Workload Command.
- Removing or changing any Linux behavior; this is purely additive.
- Linking the Virtualization Framework in-process (documented fallback only, per ADR-0001) and any non-Apple backend.
- Automating Apple-ID-gated steps (impossible; covered by the macOS Setup Checklist + `gui`).
- Raising or working around Apple's concurrent-macOS-VM cap.

## Further Notes

- Feasibility verdict (2026-06-22 fresh-eyes pass): not structurally blocked; feasibility collapses to passing the Tart spike via the `tart clone` of a prebuilt Cirrus Xcode image path. File ownership is *easier* on macOS than Linux, contrary to first intuition.
- The newly surfaced risks that were not in the original design are the virtiofs mount-location wrinkle (handled by the Guest Path symlink), Apple's ~2-VM cap, and per-VM weight — all now captured in `issues/sand/CONTEXT.md`.
- Source of truth: `issues/sand/CONTEXT.md` glossary and `docs/adr/0001-split-backends-linux-container-macos-tart.md`. This PRD should not be read as overriding either.
