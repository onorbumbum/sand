# Browser Sandboxes with a loopback Live View, and a Docker backend for Intel Hosts

Agents increasingly need a real browser, and some steps need a person: sign-ins, 2FA, captchas. A **Browser Sandbox** (`sand create <name> --browser`) runs a headed Chromium on a virtual display inside a Linux Sandbox VM. Agents in the Sandbox Guest drive it over the Chrome DevTools Protocol on guest-local `127.0.0.1:9222`. People watch and take over through a **Live View**: noVNC on guest port 6080.

The Live View is the one deliberate exception to Outbound-Only Networking. It is published on the Host Mac loopback only (`127.0.0.1:<viewPort>`, chosen at create time and stored in the Sandbox Spec), never on the LAN, and only for Browser Sandboxes. The DevTools port is never published: anything that can reach it controls the browser, so agents that need it run inside the same Sandbox VM. Remote access to the Live View belongs to a proxy that owns authentication, such as Ops behind Tailscale, which serves its own trusted viewer page and bridges only the VNC WebSocket, so nothing a Sandbox Guest serves ever runs on the proxy's origin.

The Chromium profile lives in Guest State (`/state/sandbox/chromium`), so sign-ins persist across stop/start and stay inside that Sandbox VM. Stop closes Chromium over CDP first because Chromium skips its final cookie write on SIGTERM.

Separately, Linux Sandbox VMs gain a Docker CLI backend. Apple `container` needs Apple silicon and macOS 26; the Ops host is an Intel Mac mini on macOS 15. `DockerCLIBackend` keeps the same guest contract (image, Guest State volume, Shared Folder mounts, Sandbox User, main process) through a shared `LinuxGuestRuntime` recipe. sand picks Apple `container` on Apple silicon and Docker elsewhere; `SAND_LINUX_BACKEND=docker|apple-container` overrides. With colima as the engine, only folders under the user's home are visible to the Docker VM by default.

## Considered Options

- **Browser inside the agent's own Sandbox VM, loopback Live View (chosen)**: CDP never crosses the VM boundary; one Sandbox VM per client keeps sign-ins separate.
- **Separate browser Sandbox VM that agents reach over the network**: needs CDP exposure with its own authentication; deferred until one browser must be shared across Sandbox VMs.
- **Browser on the Host Mac, exposed to Sandbox Guests**: rejected; it reverses the isolation sand exists to provide.
- **Proxy the guest's own noVNC pages through Ops**: rejected; sandbox-supplied script would run on the dashboard origin and could call its write APIs.
- **General port publishing**: still out of scope; the Live View is a single, fixed, loopback-only publish.

## Consequences

- `sand browser <name>` starts the Sandbox VM if needed and prints the Live View URL; `sand list --json` gives tools each Browser Sandbox's `browserViewPort`.
- The noVNC view has no password, which is acceptable only because it is loopback-only on a single-user Host Mac. Never widen the publish.
- Chromium runs with `--no-sandbox`; the Sandbox VM is the isolation boundary.
- On Intel Hosts, colima (or another Docker engine) is a prerequisite instead of Apple `container`; `sand doctor` reports which is missing.
