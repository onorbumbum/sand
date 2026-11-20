# Browser Sandbox Image

`sand/browser:ubuntu-lts` is the developer-ready image plus a real, headed Chromium on a virtual display. `sand create <name> --browser` uses it.

| Who | How | Where |
| --- | --- | --- |
| Agent in the sandbox | `sand-browser …` or Playwright `chromium.connectOverCDP(process.env.SAND_BROWSER_CDP)` | CDP on guest `127.0.0.1:9222`, never published |
| You | `sand browser <name>` prints the live view URL | noVNC, published on the Host Mac loopback only |

The Chromium profile lives in `/state/sandbox/chromium`, so sign-ins survive stop/start and stay inside this sandbox.

Build it after the developer-ready image:

```bash
./scripts/build-browser-image.sh
./scripts/smoke-browser-image.sh
```

Chromium runs with `--no-sandbox`: the Sandbox VM is the isolation boundary, and container seccomp blocks the user namespaces Chromium's own sandbox needs. The noVNC view has no password, which is why it is only published on `127.0.0.1`; reach it from other machines through a proxy that authenticates (Ops behind Tailscale), never by widening the publish.
