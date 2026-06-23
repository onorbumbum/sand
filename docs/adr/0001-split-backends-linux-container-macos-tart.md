# Split backends: Apple Container CLI for Linux, Tart CLI for macOS

Linux Sandbox VMs use the Apple Container CLI backend (OCI images, fast create, existing implementation). macOS Sandbox VMs use a Tart CLI backend — Tart (Cirrus Labs, open source) wraps Apple's Virtualization Framework and is the macOS analog of the Apple `container` CLI. Both backends have the same shape: shell out to a CLI that pulls an OCI image and runs it with sand-controlled directory mounts. We chose split backends over unifying everything under one runtime because each CLI is the best fit for its guest OS, and the `SandboxBackend` deep module hides the difference behind one interface.

We chose shelling out to Tart over linking the Virtualization Framework directly in `sand`'s own Swift code. Both are technically viable, but Tart already implements macOS install-from-IPSW, OCI-registry image distribution (including Xcode-preinstalled images), copy-on-write clone, directory sharing with read-only/read-write modes, SSH (`tart ip`), VNC, resource/disk configuration, and NAT/Softnet network isolation — every hard requirement sand has. Reimplementing that in-process would be substantial work and would force `sand` to carry the `com.apple.security.virtualization` entitlement and a signed-distribution pipeline. Delegating to Tart keeps `sand` unsigned and small, and is symmetric with the existing Linux backend.

## Considered Options

- **Tart CLI backend for macOS (chosen)** — symmetric with the Linux backend, no signing burden, reuses Tart's mature VF wrapper and OCI image ecosystem.
- **Link Virtualization Framework in-process** — maximum control and no external VM dependency, but requires sand to be signed with `com.apple.security.virtualization`, commits us to signed Homebrew distribution, and means reimplementing install/clone/disk-resize/networking that Tart already provides.
- **Unify both guests under one runtime (all VF, or all containers)** — rejected: Apple `container` only runs Linux; VF-managed Linux loses the fast OCI container path that Linux users depend on.
- **Depend on a GUI app (VirtualBuddy/UTM)** — rejected: those are end-user GUI apps, not scriptable CLI backends, and would not give sand control of the mount/safety boundary.

## Consequences

- `sand` requires the Tart CLI on PATH for macOS support — a CLI peer to the existing Apple `container` dependency, installable via `brew install cirruslabs/cli/tart`. `sand doctor` checks for it.
- `sand` needs no virtualization entitlement and no code signing; Tart carries the entitlement.
- macOS create is either `tart create --from-ipsw` (~30 min, self-built) or `tart clone <registry-image>` (seconds, e.g. a prebuilt Xcode image). The Apple-ID/Xcode manual setup is optional, needed only for self-built bases or device-signing.
- sand takes a dependency on Tart's roadmap and disk/image format. If Tart ever fails a hard requirement, the in-process VF option remains the documented fallback.
