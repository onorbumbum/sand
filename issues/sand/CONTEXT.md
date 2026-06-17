# Sandbox VM

This context describes the product language for a macOS app that creates and manages isolated Linux machines with explicit access to selected host folders.

## Language

**Sandbox VM**:
An isolated Linux machine with persistent guest state, terminal-style access, and explicit access to selected host folders.
_Avoid_: Pi Sandbox, generic container, Docker container

**Shared Folder**:
A host folder explicitly mounted into the Sandbox VM with an explicit access mode.
_Avoid_: Shared drive, bind mount, exposed folder

**Access Mode**:
Whether an Shared Folder is mounted read-only or read-write inside the Sandbox VM.
_Avoid_: Permission, sharing setting

**Guest Path**:
The path where an Shared Folder appears inside the Sandbox VM, defaulting to a workspace path derived from the host folder name.
_Avoid_: Mount point, target path

**Working Directory Mapping**:
The launch behavior that maps the Host Mac's current directory into the corresponding Guest Path when it is inside an Shared Folder.
_Avoid_: Always start in home, manual cd

**Sandbox Guest**:
The Linux system inside the Sandbox VM where processes may have broad/root-level control without gaining control over the Host Mac.
_Avoid_: The computer, host, local machine

**Guest State**:
The persistent filesystem state owned by the Sandbox Guest, including installed tools, shell config, package caches, and sandbox-local app config.
_Avoid_: Persistent disk, VM disk, image

**Runtime Instance**:
The disposable backend container/VM process created from Sandbox VM config, Guest State, and Shared Folders.
_Avoid_: Sandbox VM identity, guest state

**Resource Profile**:
The CPU and memory limits assigned to a Sandbox VM, defaulting to 4 CPUs and 8GB RAM with optional create-time overrides only in the first version.
_Avoid_: Resource manager, dynamic tuning

**Base Image**:
The Linux image used to create a Sandbox VM's runtime environment, defaulting to an Ubuntu LTS preset.
_Avoid_: Distro, OS choice

**Developer-Ready Sandbox**:
A Sandbox VM bootstrapped with common development tools and Pi so daily work can begin without manual Linux setup.
_Avoid_: Bare distro, raw Ubuntu

**Default Toolset**:
The baseline tools included in a Developer-Ready Sandbox: git, curl, ca-certificates, sudo, openssh-client, Python 3 with venv/pip, Node/npm, tmux, ripgrep, build-essential, and the Pi CLI.
_Avoid_: Random packages, user dotfiles

**Sandbox Image**:
A prebuilt OCI image that contains the Base Image plus the Default Toolset for fast, reproducible Sandbox VM creation.
_Avoid_: First-run bootstrap, mutable base distro

**Sandbox User**:
The default non-root Linux user inside the Sandbox Guest used for daily shell and Pi sessions, with passwordless sudo available when needed.
_Avoid_: root user, host user

**Host-Safe File Ownership**:
The requirement that files created or modified through read-write Shared Folders remain editable and deletable by the Host Mac user without sudo.
_Avoid_: Root-owned project files, UID surprises

**Outbound-Only Networking**:
The default networking rule that allows Sandbox Guest processes to reach the internet while exposing no inbound services from the Sandbox VM.
_Avoid_: Port forwarding, localhost publishing

**Pi Identity**:
The sandbox-local Pi configuration and credentials that make Pi behave as if the Sandbox VM is its own computer.
_Avoid_: Host Pi config, shared ~/.pi

**Guest Secret**:
A credential or token stored inside Guest State rather than mounted, forwarded, or copied from the Host Mac by default.
_Avoid_: Host secret, forwarded token, mounted credential

**Sandbox Session**:
An interactive shell connection into the Sandbox VM as the Sandbox User, without prompting for guest username or password, regardless of whether the transport is SSH, container exec, or another backend mechanism.
_Avoid_: SSH-only workflow, embedded Pi runner, manual login

**Lifecycle Mutation**:
A change that creates, deletes, resets, starts, stops, applies, or reconfigures a Sandbox VM or its Runtime Instance.
_Avoid_: Normal session, workload run

**Apply**:
The declarative reconciliation action that makes backend reality match a Sandbox Spec, using runtime recreation internally only when required.
_Avoid_: User-facing recreate, manual backend repair

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
The declarative YAML definition of a Sandbox VM, including name, image, Resource Profile, Shared Folders, Guest Paths, and Access Modes, while excluding unsupported future concerns such as inbound networking in the first version.
_Avoid_: Hidden imperative setup, backend-only config, future config placeholders

**Host Metadata**:
The `sand`-owned management data stored on the Host Mac, separate from Guest State, including sandbox specs, backend IDs, and schema version.
_Avoid_: Guest state, dotfiles inside sandbox

**Sandbox Status**:
The concise user-facing state of a Sandbox VM, including whether it is running or stopped plus key configuration details.
_Avoid_: Backend dump, raw inspect output

**Doctor Check**:
A diagnostic command that verifies host/backend prerequisites such as Apple container availability, service status, platform support, default image availability, and Host Metadata writability.
_Avoid_: Full health dashboard, generic troubleshooting wizard

**Backend Service**:
The Apple container system service used by the first backend, treated as implementation plumbing that `sand` starts automatically when needed.
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
- A **Sandbox VM** is created from a **Base Image**, with Ubuntu LTS as the default preset.
- The default **Sandbox VM** is a **Developer-Ready Sandbox**, not a bare Linux install.
- A **Developer-Ready Sandbox** includes the **Default Toolset**.
- The default **Developer-Ready Sandbox** is created from a **Sandbox Image** rather than installing all tools during first create.
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
- The first **Sandbox Backend** shells out to Apple `container`, but backend details must not leak into the API Surface or Sandbox Spec.
- A **Backend Validation Spike** must pass before committing to the Apple `container` CLI backend.
- If the Apple `container` CLI fails hard requirements, evaluate direct Apple Containerization Swift APIs; if that also fails, stop rather than falling through to non-Apple backends.

## Example dialogue

> **Dev:** "Is this a Pi-specific launcher?"
> **Domain expert:** "No — it is a **Sandbox VM** app. Pi is the first thing I want to run there, but the sandbox should feel like a small Linux computer I can terminal or SSH into."

## Flagged ambiguities

- "container" was used to mean an isolated Linux VM-style environment, not a generic Docker-style app container.
- "Pi Sandbox" was initially used for the product concept, but that over-coupled the app to Pi. Resolved: use **Sandbox VM** for the product concept, with Pi as a workload inside it.
- "documentation" was used broadly to mean onboarding, behavior reference, domain language, architecture rationale, and web-readable pages. Resolved: use **Documentation System** for the integrated whole and **Documentation Impact** for per-change obligations.
- "Bosun workflow" was considered for documentation generation, but that may be premature automation. Resolved: start with a manual agent-run **Documentation Refresh Workflow** and introduce Bosun only when the workflow proves complex enough.
