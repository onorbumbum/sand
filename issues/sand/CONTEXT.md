# Sandbox VM

This context describes the product language for a macOS app that creates and manages isolated virtual machines with explicit access to selected host folders.

## Language

**Sandbox VM**:
An isolated virtual machine running a supported guest OS (Linux or macOS), with persistent guest state, terminal-style access, and explicit access to selected host folders. The guest OS is a property of the spec; Linux is the default.
_Avoid_: Pi Sandbox, generic container, Docker container, "Linux machine" as a fixed product property

**Shared Folder**:
A host folder explicitly mounted into the Sandbox VM with an explicit access mode.
_Avoid_: Shared drive, bind mount, exposed folder

**Access Mode**:
Whether an Shared Folder is mounted read-only or read-write inside the Sandbox VM.
_Avoid_: Permission, sharing setting

**Guest Path**:
The path where an Shared Folder appears inside the Sandbox VM, defaulting to a workspace path derived from the host folder name. The same chosen/derived path is presented on both backends: on Linux the host folder is bind-mounted there directly; on macOS the backend mounts via virtiofs at the OS-fixed location (`/Volumes/My Shared Files/<tag>`) and creates a guest-side symlink from the Guest Path to it, so the fixed virtiofs location stays a hidden backend detail and `--as`/Working Directory Mapping behave identically across backends.
_Avoid_: Mount point, target path, exposing `/Volumes/My Shared Files` as the user-facing path

**Working Directory Mapping**:
The launch behavior that maps the Host Mac's current directory into the corresponding Guest Path when it is inside an Shared Folder.
_Avoid_: Always start in home, manual cd

**Sandbox Guest**:
The guest operating system inside the Sandbox VM (Linux or macOS) where processes may have broad/admin-level control without gaining control over the Host Mac.
_Avoid_: The computer, host, local machine

**Guest State**:
The persistent filesystem state owned by the Sandbox Guest, including installed tools, shell config, package caches, and sandbox-local app config. Backed by a dedicated `/state` volume on Linux (separate from the ephemeral container rootfs) and by the VM's own disk image on macOS (no rootfs/state separation). Persists between launches unless the Sandbox VM is deleted.
_Avoid_: Ephemeral-only state, conflating with the Base Image

**Runtime Instance**:
The disposable backend container/VM process created from Sandbox VM config, Guest State, and Shared Folders.
_Avoid_: Sandbox VM identity, guest state

**Resource Profile**:
The CPU and memory limits assigned to a Sandbox VM, with create-time overrides. Defaults are guest-OS-dependent: Linux 4 CPUs / 8GB RAM; macOS 4 CPUs / 16GB RAM (Xcode-appropriate). CPU and memory are immutable after create.
_Avoid_: Resource manager, dynamic tuning

**Disk Size**:
The fixed size of a macOS Sandbox VM's disk image, chosen at create-time (fresh install or clone) and defaulting to ~100GB. Grow-only: a Clone's disk must be greater than or equal to its source because APFS cannot reliably shrink the system container. Not applicable to Linux, whose containers grow on demand against the host filesystem. Not resizable in place after create.
_Avoid_: Linux disk quota, in-place shrink, post-create resize via apply

**Base Image**:
The image used to create a Sandbox VM's runtime environment. For Linux, a prebuilt OCI image (Ubuntu LTS default) run via Apple `container`. For macOS, either a prebuilt OCI image pulled via Tart from a registry (e.g. `ghcr.io/cirruslabs/macos-sequoia-xcode`) or a fresh install from an Apple IPSW (`tart create --from-ipsw`). In both backends the model is identical: pull an OCI image and run it.
_Avoid_: Distro, OS choice

**Developer-Ready Sandbox**:
A Sandbox VM bootstrapped with common development tools and Pi so daily work can begin without manual setup. Linux: includes the Default Toolset. macOS: a prebuilt Tart image (e.g. `macos-sequoia-xcode`) that already ships Xcode, or a self-built VM with SSH, Screen Sharing, the Sandbox User, and Xcode CLI tools plus the macOS Setup Checklist for the Apple-ID-gated remainder.
_Avoid_: Bare distro, raw macOS, bare install

**Default Toolset**:
The baseline tools included in a Linux Developer-Ready Sandbox: git, curl, ca-certificates, sudo, openssh-client, Python 3 with venv/pip, Node/npm, tmux, ripgrep, build-essential, and the Pi CLI.
_Avoid_: Random packages, user dotfiles

**macOS Install Flow**:
The flow triggered by `sand create <name> --os macos` for building a macOS Sandbox VM from scratch. Sand wraps `tart create --from-ipsw`, then sets resources, enables SSH, and configures the Sandbox User. Used when the user wants a self-built base rather than a prebuilt registry image. Takes ~30 minutes. No third-party virtualization GUI app is involved; the only dependency is the Tart CLI.
_Avoid_: Requiring VirtualBuddy/UTM, reimplementing install in-process, one fixed configuration

**Clone**:
Creating a new macOS Sandbox VM from an existing one (or a registry image) via `sand create <name> --from <source>`, wrapping `tart clone` (copy-on-write, seconds). The source may be a local macOS Sandbox VM kept clean by convention, or a prebuilt OCI image such as `ghcr.io/cirruslabs/macos-sequoia-xcode`. There is no separate first-class "base" concept.
_Avoid_: Base VM as a first-class concept, `sand base` subcommand, protected templates

**macOS Setup Checklist**:
The documented, optional, one-time list of manual Apple-ID-gated steps for a self-built macOS Sandbox VM: signing into Apple ID, installing full Xcode, installing simulator runtimes, and (only if automatic signing management is wanted) enabling Xcode's automatic signing. Done once via `sand gui <name>` on a sandbox the user then clones from; the result persists in Guest State and into every Clone, so it is not a per-build gate. Optional because a prebuilt Tart image (e.g. `macos-sequoia-xcode`) already ships Xcode, and because distribution code signing does NOT require it (see **Signing Credentials**). Apple gates the interactive Apple-ID login behind authentication that no tool can automate, which is the only irreducibly manual part.
_Avoid_: Undocumented manual steps, assuming the checklist is always required, conflating distribution signing with Apple-ID login, claiming full automation

**Signing Credentials**:
A macOS developer's code-signing certificate (`.p12`) and provisioning profile, injected into the Sandbox Guest's keychain as a **Guest Secret** so `xcodebuild` can sign builds for distribution (TestFlight, App Store, ad-hoc, enterprise) headlessly — no interactive Apple-ID login and no GUI. The standard CI signing model; in scope for macOS Sandbox VMs.
_Avoid_: Requiring Apple-ID login to sign, mounting host keychain, conflating signing with physical-device deployment

**Sandbox Image**:
A prebuilt OCI image that contains the Base Image plus the Default Toolset for fast, reproducible Linux Sandbox VM creation.
_Avoid_: First-run bootstrap, mutable base distro

**Sandbox User**:
The default non-administrator user account inside the Sandbox Guest used for daily shell and Pi sessions, with passwordless sudo/admin escalation available when needed. A Linux user on Linux guests; a macOS user account on macOS guests.
_Avoid_: root user, host user

**Host-Safe File Ownership**:
The requirement that files created or modified through read-write Shared Folders remain editable and deletable by the Host Mac user without sudo.
_Avoid_: Root-owned project files, UID surprises

**Outbound-Only Networking**:
The default networking rule that allows Sandbox Guest processes to reach the internet while exposing no inbound services to the external network or LAN. Host-local control channels are allowed and are how sand operates: the Linux backend's `container exec`, and the macOS backend's SSH and Screen Sharing, which are reachable only from the Host Mac over the backend's private NAT, never from other machines. The hard guarantee is that no other machine on the network can reach the Sandbox VM.
_Avoid_: Port forwarding to the LAN, localhost publishing, binding guest services to 0.0.0.0

**Pi Identity**:
The sandbox-local Pi configuration and credentials that make Pi behave as if the Sandbox VM is its own computer.
_Avoid_: Host Pi config, shared ~/.pi

**Guest Secret**:
A credential or token stored inside Guest State rather than mounted, forwarded, or copied from the Host Mac by default.
_Avoid_: Host secret, forwarded token, mounted credential

**Sandbox Session**:
An interactive shell connection into the Sandbox VM as the Sandbox User, without prompting for guest username or password, regardless of whether the transport is SSH, container exec, or another backend mechanism.
_Avoid_: SSH-only workflow, embedded Pi runner, manual login

**GUI Session**:
A graphical desktop connection into a macOS Sandbox VM, opened by `sand gui <name>`, which runs the VM with Tart's VNC server (`tart run --vnc`) and launches the host macOS Screen Sharing app pointed at the resulting VNC address. Not applicable to Linux Sandbox VMs.
_Avoid_: Embedded VNC viewer, manual VNC setup, remote desktop client

**Lifecycle Mutation**:
A change that creates, deletes, resets, starts, stops, applies, or reconfigures a Sandbox VM or its Runtime Instance.
_Avoid_: Normal session, workload run

**Apply**:
The declarative reconciliation action that makes backend reality match a Sandbox Spec. Shared folder changes trigger runtime recreation on Linux (stop → delete runtime → recreate → restart, Guest State preserved) and a stop/update/restart on macOS (no disk touched). CPU and memory are immutable after create and are rejected by apply. Image changes are rejected after create. The recreation mechanism is internal — the Sandbox VM identity and Guest State are never affected.
_Avoid_: User-facing recreate, manual backend repair, "apply does whatever is needed" (too vague)

**Workload Command**:
A command and arguments executed inside a Sandbox Session after sandbox lifecycle and working-directory mapping are handled.
_Avoid_: Pi-only command, sand-native app flag

**Pi Workload**:
Pi executed as a normal Workload Command inside a Sandbox Session, without special `sand` semantics.
_Avoid_: Pi launch, Pi-specific command, agent launcher

**Sandbox Name**:
The user-chosen name for a Sandbox VM used in commands and management flows.
_Avoid_: Computer name, VM id, container name

**API Surface**:
The user-facing way to create, configure, launch, and inspect Sandbox VMs, named `sand` for the first Swift CLI.
_Avoid_: UI, frontend

**Documentation System**:
The integrated project documentation made from onboarding docs, domain language, decision records, executable behavior specs, and generated web-readable pages.
_Avoid_: Wiki, docs folder, single source document

**Documentation Freshness Gate**:
A deterministic project check that prevents documentation from drifting by requiring behavior claims to be generated from or validated against source-of-truth artifacts.
_Avoid_: Remember to update docs, best-effort documentation

**Generated Documentation**:
Committed human-facing documentation produced by a Documentation Refresh Workflow from code, tests, CLI help, domain language, and decisions.
_Avoid_: Ephemeral docs, untracked generated output, LLM-only source of truth

**Managed Section**:
A marked region inside an otherwise hand-authored document that the Documentation Refresh Workflow may update.
_Avoid_: Full-document overwrite, hidden generated prose

**Documentation Refresh Workflow**:
A repeatable agent-run workflow, initially a checked-in prompt plus scripts and later optionally Bosun, that refreshes Generated Documentation from current project inputs.
_Avoid_: Ad hoc doc writing, mandatory Bosun automation, manual memory

**Documentation Input Manifest**:
The curated list of project files whose changes mean Generated Documentation may be stale.
_Avoid_: Hash every file, watch the whole repo, rely on memory

**Onboarding Guide**:
A generated start-here document for humans and agents that explains the repo map, first files to read, and build/test/run workflow.
_Avoid_: Scattered setup notes, tribal onboarding

**CLI Reference**:
A generated command reference derived from actual `sand` help output and command definitions.
_Avoid_: Hand-maintained command docs, stale option list

**Developer Guide**:
A generated guide for changing `sand`, covering architecture, testing strategy, command implementation workflow, and documentation update workflow.
_Avoid_: Contributor folklore, implementation tour in README

**Documentation Impact**:
The explicit per-change classification of whether README, domain language, ADRs, web docs, or executable specs must change.
_Avoid_: Docs maybe, cleanup later

**Sandbox Spec**:
The declarative YAML definition of a Sandbox VM, including name, guest OS, image, Resource Profile, Shared Folders, Guest Paths, Access Modes, and (macOS only) Disk Size, while excluding unsupported future concerns such as inbound networking. The spec is guest-OS-agnostic except for the macOS-only Disk Size field, which is an honest reflection that disk provisioning is a macOS-only concern.
_Avoid_: Hidden imperative setup, backend-only config, future config placeholders

**Host Metadata**:
The `sand`-owned management data stored on the Host Mac, separate from Guest State, including sandbox specs, backend IDs, schema version, and (macOS only) the per-sandbox SSH private key sand generates at create to reach the guest non-interactively.
_Avoid_: Guest state, dotfiles inside sandbox

**Sandbox Status**:
The concise user-facing state of a Sandbox VM, including whether it is running or stopped plus key configuration details.
_Avoid_: Backend dump, raw inspect output

**Doctor Check**:
A diagnostic command that verifies host/backend prerequisites. For the Linux backend: Apple container availability, service status, default image availability. For the macOS backend: Apple Silicon host, supported macOS host version, and Tart CLI availability/version on PATH. Shared: platform support and Host Metadata writability.
_Avoid_: Full health dashboard, generic troubleshooting wizard

**Backend Service**:
The Apple container system service used by the Linux backend, treated as implementation plumbing that `sand` starts automatically when needed. The macOS backend has no equivalent daemon — it shells out to the Tart CLI per command, the same shape as the Linux backend shelling out to `container`.
_Avoid_: User-managed daemon, manual prerequisite step

**Sandbox Backend**:
A deep module that hides backend-specific container/VM operations behind a shallow interface for backend readiness, provisioning, applying specs, lifecycle, command execution, status, logs, and deletion.
_Avoid_: Leaky wrapper, command-shaped abstraction, backend logic spread through CLI commands

**Backend Validation Spike**:
A required pre-implementation check that proves the chosen backend can satisfy hard product requirements before the full CLI is built.
_Avoid_: Assumed backend fit, speculative wrapper

**Host Mac**:
The user's macOS system outside the Sandbox VM, protected from sandbox processes except through Shared Folders.
_Avoid_: Parent machine, main computer

## Relationships

- A **Sandbox VM** contains a **Sandbox Guest**.
- A **Sandbox VM** can access only **Shared Folders** from the **Host Mac**.
- Each **Shared Folder** has an **Access Mode** and a **Guest Path**.
- Folder commands accept `rw`/`read-write` and `ro`/`read-only`, while the **Sandbox Spec** stores canonical `read-write` and `read-only` terms.
- Adding an existing host folder updates its **Access Mode** or **Guest Path** instead of creating a duplicate.
- Two different **Shared Folders** cannot share the same **Guest Path**.
- Overlapping host folders are rejected in the first version to keep access rules and working-directory mapping unambiguous.
- Folder validation and **Working Directory Mapping** use resolved real paths while preserving user-facing display paths.
- A **Sandbox VM** may be created with no **Shared Folders**, though folder setup is part of the coding-agent happy path.
- Processes may have broad control inside the **Sandbox Guest** without having broad control over the **Host Mac**.
- **Guest State** persists between launches unless the user deletes the **Sandbox VM**.
- A **Runtime Instance** may be recreated to apply configuration changes without changing the **Sandbox VM** identity.
- A **Sandbox VM** has a **Resource Profile**.
- A **Sandbox VM** is created from a **Base Image**, with Ubuntu LTS as the default preset for Linux guests.
- The default Linux **Sandbox VM** is a **Developer-Ready Sandbox**, not a bare Linux install.
- A **Developer-Ready Sandbox** includes the **Default Toolset**.
- The default **Developer-Ready Sandbox** is created from a **Sandbox Image** rather than installing all tools during first create.
- macOS **Sandbox VMs** use a different **Sandbox Backend** (the Tart CLI, which wraps Apple's Virtualization Framework) than Linux **Sandbox VMs** (Apple Container CLI). Both backends shell out to a CLI that pulls an OCI image and runs it with sand-controlled mounts. The guest OS type is set at create time and is immutable.
- The **Sandbox Backend** for a given **Sandbox VM** is determined by its guest OS and is not user-configurable.
- A macOS **Sandbox VM** is created either by the **macOS Install Flow** (`--os macos`, `tart create --from-ipsw`, ~30 min) or by **Clone** (`--from <source-or-registry-image>`, `tart clone`, seconds).
- There is no first-class "base" concept; a **Clone** source is a stopped macOS **Sandbox VM** kept clean by convention, or a prebuilt registry image. The `--from` flag unifies Linux image templates and macOS clone sources.
- A macOS **Sandbox VM** is reached over hidden SSH (`tart ip` + ssh) for **Sandbox Sessions** and **Workload Commands**; Tart/VF has no container-exec equivalent.
- A macOS **Sandbox VM** needs the **macOS Setup Checklist** only when self-built; prebuilt Tart images can ship Xcode preinstalled.
- A macOS **Sandbox VM** can build/run in the Simulator (no signing) and code-sign for distribution via injected **Signing Credentials** (no Apple-ID login, no GUI). Automatic signing via Apple ID is an optional one-time GUI step that persists in Guest State and Clones.
- Deploying or debugging on a **physical** iOS device is out of scope: Apple's Virtualization Framework provides no USB passthrough for macOS guests (a platform limit, not a Tart or `sand` choice), so a host-connected device is invisible to the Sandbox Guest. `sand gui <name>` gives graphical access to the VM's own desktop, not host-device forwarding.
- `sand` does not need the `com.apple.security.virtualization` entitlement or code signing, because Tart (which carries the entitlement) owns the Virtualization Framework calls. `sand` requires the Tart CLI on PATH, a CLI peer to the Apple `container` dependency.
- Daily **Sandbox Sessions** run as the **Sandbox User**, not root.
- Read-write **Shared Folders** must preserve **Host-Safe File Ownership**.
- **Sandbox VMs** use **Outbound-Only Networking** by default; inbound port publishing is out of scope for the first version.
- Runtime recreation is mostly an internal repair/config-application step, not a normal user-facing lifecycle concept.
- **Apply** is the user-facing declarative reconciliation command; recreate remains hidden/internal.
- CLI configuration mutations update the **Sandbox Spec** and auto-apply by default.
- Configuration changes that require runtime recreation apply immediately when stopped and ask before interrupting a running **Sandbox VM**.
- **Lifecycle Mutations** are serialized, but normal **Sandbox Sessions** and **Workload Commands** are concurrent.
- **Pi Identity** lives in **Guest State** by default, not in the Host Mac's Pi configuration.
- Credentials used by the **Sandbox VM** are **Guest Secrets** only in the first version.
- Pi is the primary internal workload for the default **Sandbox VM**, but not the product boundary itself.
- A **Sandbox Session** lets the user enter the **Sandbox VM** through terminal-style access; SSH is optional because the domain need is shell access.
- Multiple **Sandbox Sessions** may run concurrently against the same **Sandbox VM**.
- A **Workload Command** is passed through to the **Sandbox Guest** without `sand` understanding the workload's own flags.
- The first version avoids explicit TTY policy: `shell` is interactive, and `run` behaves naturally for the current terminal.
- A **Pi Workload** is invoked through the generic `run` action, e.g. `sand mybox run pi [args...]`.
- `sand` does not provide a Pi-specific shortcut in the first version.
- **Working Directory Mapping** starts sessions in the matching **Guest Path** when the host current directory is inside an **Shared Folder**; otherwise sessions warn and start in `/workspace` or the **Sandbox User** home.
- `sand create` writes and applies the initial **Sandbox Spec**, provisions **Guest State**, and leaves the **Sandbox VM** in the stopped state.
- Daily commands auto-start the target **Sandbox VM** when it is stopped.
- Each **Sandbox VM** has a globally unique per-user **Sandbox Name** for CLI commands and management.
- Daily CLI syntax is sandbox-first and explicit: `sand <sandbox-name> <action>`.
- The first version has no default sandbox or project-local implicit sandbox selection.
- The first **API Surface** is a Swift CLI; any desktop UI should wrap the same underlying sandbox model later.
- The **Documentation System** uses executable behavior specs as the source of truth for behavior, with human-facing docs generated from or checked against those specs.
- **Generated Documentation** is committed to the repository rather than generated only on demand.
- The first **Generated Documentation** set is `README.md`, **Onboarding Guide** at `docs/onboarding.md`, **CLI Reference** at `docs/cli-reference.md`, and **Developer Guide** at `docs/developer-guide.md`.
- `README.md` is section-managed with **Managed Sections** rather than fully generated.
- **CLI Reference** is fully generated, while **Onboarding Guide** and **Developer Guide** may combine generated sections with preserved human-authored sections.
- The first **Documentation Refresh Workflow** is a manual agent-run workflow using a checked-in prompt plus deterministic scripts rather than Bosun automation.
- Bosun is only introduced later if documentation refresh needs multiple LLM passes, structured intermediate artifacts, review loops, generated diagrams, resumability, or publishing automation.
- A future Bosun documentation workflow may produce rich tutorials, onboarding guides, and web-readable pages, but the **Documentation Freshness Gate** remains deterministic and cheap.
- A **Documentation Freshness Gate** is mandatory before project work is considered complete.
- A **Documentation Freshness Gate** fails when the current **Documentation Input Manifest** hash differs from the hash recorded in Generated Documentation.
- The first **Documentation Input Manifest** is curated around public behavior, command surface, domain language, README, and documentation refresh prompt changes rather than every source file.
- A **Sandbox Spec** is the source of truth for a **Sandbox VM**.
- `sand <sandbox-name> spec` prints the active **Sandbox Spec**; editor integration is omitted in the first version.
- `sand create` generates a **Sandbox Spec** in **Host Metadata** by default, while `sand create --from` supports user-authored specs.
- **Host Metadata** lives under `~/.sand/` on the **Host Mac** and stores active **Sandbox Specs**.
- Destructive deletion prompts by default and requires an explicit force option to skip confirmation.
- The first version omits a separate reset command; delete plus create is the explicit destructive flow.
- `sand list` and `sand <sandbox-name> status` show **Sandbox Status** rather than raw backend details.
- The first command surface is `doctor`, `create`, `list`, `apply`, `delete`, sandbox-first `status/start/stop/shell/run/logs/spec`, and `folders add/list/remove`.
- Implementation is test-first around the domain/spec layer before backend integration work.
- The first version includes minimal diagnostics through `sand doctor` and `sand <sandbox-name> logs`.
- `sand` auto-starts the **Backend Service** when needed and reports failures clearly.
- The Linux **Sandbox Backend** shells out to Apple `container`; the macOS **Sandbox Backend** shells out to Tart. Backend details must not leak into the API Surface or Sandbox Spec.
- A **Backend Validation Spike** must pass before committing to each CLI backend.
- If the Apple `container` CLI fails Linux hard requirements, evaluate direct Apple Containerization Swift APIs; if that also fails, stop rather than falling through to non-Apple backends.
- If the Tart CLI fails macOS hard requirements, the documented fallback is linking Apple's Virtualization Framework directly in `sand` (which would reintroduce the signing/entitlement requirement). See ADR 0001.

## Example dialogue

> **Dev:** "Is this a Pi-specific launcher?"
> **Domain expert:** "No — it is a **Sandbox VM** app. Pi is the first thing I want to run there, but the sandbox should feel like a small Linux computer I can terminal or SSH into."

## Flagged ambiguities

- "container" was used to mean an isolated Linux VM-style environment, not a generic Docker-style app container.
- "Pi Sandbox" was initially used for the product concept, but that over-coupled the app to Pi. Resolved: use **Sandbox VM** for the product concept, with Pi as a workload inside it.
- "documentation" was used broadly to mean onboarding, behavior reference, domain language, architecture rationale, and web-readable pages. Resolved: use **Documentation System** for the integrated whole and **Documentation Impact** for per-change obligations.
- "Bosun workflow" was considered for documentation generation, but that may be premature automation. Resolved: start with a manual agent-run **Documentation Refresh Workflow** and introduce Bosun only when the workflow proves complex enough.

## Handoff for the next grilling session

A grilling session on **2026-06-22** added macOS Sandbox VM support to the previously Linux-only design. This section orients the next agent so settled ground is not re-litigated and open ground is picked up cleanly. The glossary above and `docs/adr/0001-split-backends-linux-container-macos-tart.md` are the source of truth; this is a map, not a substitute.

### Settled — do not reopen without new information

- **Additive, not replacement.** Linux sandboxes stay for lightweight work; macOS VMs are for Xcode/iOS builds. Both are first-class.
- **"Sandbox VM" is guest-OS-agnostic.** Linux is the default; guest OS is a spec property set at create and immutable.
- **Split backends, both shell-out-to-a-CLI.** Apple `container` for Linux, **Tart** for macOS. Symmetric model: each pulls an OCI image and runs it with sand-controlled mounts. The `SandboxBackend` deep module hides the difference.
- **Tart over in-process Virtualization Framework.** Verified Tart meets every hard requirement (create-from-IPSW, OCI clone incl. prebuilt Xcode images, rw/ro dir mounts, SSH via `tart ip`, VNC, cpu/mem/disk config, NAT/Softnet isolation). Consequence: `sand` needs **no** code signing or virtualization entitlement; it requires the `tart` CLI on PATH. In-process VF is the documented fallback only if Tart fails a hard requirement.
- **No first-class "base" concept.** `--from` unifies Linux image templates and macOS clone sources; a clean clone source is a convention.
- **Transport:** hidden SSH for shell/run; `sand gui <name>` runs `tart run --vnc` and auto-opens the host Screen Sharing app.
- **Guest State** on macOS is the whole VM disk. **Disk Size** is a macOS-only, grow-only, create-time spec field. **Outbound-Only Networking** refined to "no inbound from LAN/internet; host-local control channels allowed."

### Open — needs validation or a decision

1. **Backend Validation Spike for Tart (mandatory before build).** Prove on real Apple Silicon hardware that `tart` satisfies every hard requirement end-to-end. CONTEXT.md already requires a spike per backend.
2. **Verify Tart's NAT binds SSH/VNC host-only, not to the LAN** — backs the Outbound-Only guarantee.
3. **Verify virtiofs writes land as the host user** — backs Host-Safe File Ownership on macOS. Expected low-risk: Virtualization.framework virtiofs creates guest-written files on the host owned by the user who launched the VM, so there is no uid-translation problem like Linux has. Downgraded from blocker to a 5-minute spike confirmation (write from guest → `ls -l` on host → owned by host user, editable without sudo).
4. **Credential handling at create** — RESOLVED (2026-06-22): generate a per-sandbox SSH keypair at create/clone, inject the public key into the macOS guest's `authorized_keys`, store the private key in **Host Metadata** (`~/.sand/`), and use the key (not the baked-in `admin`/`admin` password) for all sand sessions. The default password stays only as documented break-glass for `sand gui <name>`. Spike must prove: clone → key injected → `sand <name> shell` connects with zero prompt. Contained today by **Outbound-Only Networking** (SSH host-only over private NAT); the key approach keeps it honest if inbound is ever added.
5. **Spec schema evolution** — RESOLVED (2026-06-22): additive optional fields, NO `schemaVersion` bump (bump is reserved for breaking changes; this is additive). Parser learns `os: linux|macos` (default `linux`, so existing specs stay valid) and `disk: <size>` (macOS-only). Add three rules mirroring existing immutability gates: `disk` rejected when `os != macos`; `os` immutable after create (join the image/cpu/memory immutable set in `validateUpdate`); `disk` grow-only on clone, in-place resize rejected. `SandboxSpec.parseYAML` currently throws `unsupportedField` on any unknown top-level key (lines 148–150), so these two keys must be taught explicitly.
6. **Resource defaults** — macOS default set to 4 CPU / 16GB on paper; confirm against real Xcode builds.
7. **Trust posture on prebuilt third-party (Cirrus) macOS+Xcode images** — acceptable default, or require self-built? Currently offered as the easy path with self-build as the alternative.
8. **Apple's 2-VM concurrent limit on macOS guests (platform constraint, missing from glossary).** Apple's macOS license on Apple Silicon permits running at most ~2 macOS VMs concurrently per host; Linux guests are uncapped. This dents the "spin up as many sandboxes as I want" mental model for macOS guests specifically. Confirm the exact limit, then document it as a known constraint rather than discovering it at macOS sandbox #3.
9. **Per-macOS-VM weight (missing from glossary).** Each macOS Sandbox VM is ~100GB disk and boots slower than a Linux container. Combined with #8, the honest framing is "a handful of macOS sandboxes," not "dozens."
10. **macOS Guest Path via symlink (must-prove in spike).** Decision (2026-06-22): preserve the chosen Guest Path by symlinking it to the fixed virtiofs mount `/Volumes/My Shared Files/<tag>` (see **Guest Path**). Spike must prove a real Xcode project opens, builds, and resolves `DerivedData` correctly when the project lives behind that symlink — Xcode is historically sensitive to symlinked paths.

### Feasibility verdict (2026-06-22 fresh-eyes pass)

The architecture is not structurally blocked; feasibility collapses to passing the Tart spike (#1). Prove it via the **`tart clone` of a prebuilt Cirrus Xcode image path first** — seconds to create, Xcode preinstalled, no Apple-ID gating, covers simulator/CI-style iOS builds. The self-built IPSW + Apple-ID + on-device-signing path (**macOS Install Flow**, **macOS Setup Checklist**) contains irreducibly manual steps and should stay off the feasibility critical path unless on-device signing becomes a hard requirement.

### Stale-but-deliberate

- The **Example dialogue** quote ("small Linux computer") is a historical record of the original Linux-only intent; left as-is. A macOS-era dialogue line could be added if the next session wants to capture the evolved framing.
