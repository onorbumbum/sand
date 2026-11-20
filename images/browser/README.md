# Browser Sandbox Image

`sand/browser:ubuntu-lts` is the developer-ready image plus a real, headed browser on a resizable virtual display. `sand create <name> --browser` uses it. Design and trade-offs: [ADR 0002](../../docs/adr/0002-browser-sandboxes-and-docker-backend.md).

| Who | How | Where |
| --- | --- | --- |
| Agent in or beside the sandbox | `sand-browser …` (or Playwright `chromium.connectOverCDP(process.env.SAND_BROWSER_CDP)`) | DevTools on guest `127.0.0.1:9222`, never published |
| Person | `sand browser <name>` prints the Live View URL; Ops proxies it as Live Browsers | noVNC, published on the Host Mac loopback only |

What is inside:

- **Browser:** Google Chrome on amd64; Playwright's Chrome for Testing on arm64 (no Google Chrome arm64 Linux build). The profile lives in `/state/sandbox/chromium`, so sign-ins and tabs survive stop/start; stop closes the browser over CDP so its cookie store is written.
- **Display:** TigerVNC `Xvnc` (accepts the viewer's resize, so the screen follows the window), openbox keeping windows maximized and frameless (`openbox.xml`), websockify/noVNC on guest port 6080.
- **`sand-browser-up`:** the main process; restarts the browser if it is closed or crashes.
- **`sand-browser`:** the agent CLI (`sand-browser --help`): status, tabs, tree, text, html, screenshot; open (`--new`, `--wait load|idle`), back, forward, reload, click, fill, type, select, key, scroll, wait, eval, close; named tabs (tab-new, tab-use, tab-close, `--tab <name>`); activity (JSON for Ops); downloads, download-get, download-open, download-delete; uploads, upload-put, upload, upload-delete. `tree` prints the page as an accessibility tree with refs (`button "Save" [ref=e3]`) and tags those elements with `data-sand-ref`, so a later call can act on `@e3` (Playwright's own refs end with each call's CDP connection); a ref the page has since dropped fails with "run sand-browser tree again". Tab names and the default tab live in `/state/sandbox/sand-browser-tabs.json`, keyed by CDP target id. While Onur has control (`/tmp/sand-browser-held`), acting commands exit 75.
- **Files:** two Guest State folders are the only way across, `/state/sandbox/Downloads` and `/state/sandbox/Uploads` (also `~/Downloads`, `~/Uploads`). Files there are never overwritten and appear only when complete.
- **`xdg-open`:** opening a file in the sandbox shows it in a new browser tab; GTK 3 gives the browser its file picker.

Build and check, after the developer-ready image:

```bash
./scripts/build-browser-image.sh
./scripts/smoke-browser-image.sh
```

The noVNC view has no password, which is why it is only published on `127.0.0.1`; reach it from other machines through a proxy that authenticates (Ops behind Tailscale), never by widening the publish. The browser runs with `--no-sandbox`: the Sandbox VM is the isolation boundary.
