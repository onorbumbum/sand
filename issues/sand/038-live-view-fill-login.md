---
title: Live View: Fill login from the password manager
status: in-progress
type: issue
category: migration
labels:
  - sand
  - aslan-browser-retirement
  - ops
  - live-view
  - security
created: 2026-11-20
---

## Parent

- `issues/sand/prd-retire-aslan-browser.md`

## What to build

Replace Aslan's Bitwarden-backed sign-in. Decision first (PRD): Bitwarden session on the Mini, or not. If yes: the viewer gets Fill login; Ops lists vault items matching the page's host; Onur picks one; Ops types username and password into the focused fields as key events. The secret never reaches an agent, an `/api/*` response, the activity log or a file.

## Acceptance criteria

- [x] Onur-initiated only; no agent-callable path.
- [x] Tests prove the secret is absent from API responses, logs and `sand-browser activity`.
- [x] Works while Onur has control; refused otherwise.

## Blocked by

- `issues/sand/037-client-browser-sandboxes.md`

## Progress

### 2026-11-20 — Fill login built; needs Bitwarden unlocked on the Mini

Decision (Onur, 2026-11-20): a Bitwarden session on the Mini is acceptable.

- Guest: `images/browser/sand-browser-fill-login` (image now has `xdotool`) reads username and password on stdin and types username, Tab, password into the focused field on the browser's display; never Enter; exit 75 unless `/tmp/sand-browser-held` exists. Smoke: "fill login types into the focused field -> ok" (special characters, refused when not held).
- Ops (`sandbox_browser.clj`): `logins` lists Bitwarden login items whose URIs fit a host open in the sandbox (`bw list items --url`, own host check: same host or subdomain, so `evilgoogle.com` does not match `google.com`) and returns id, name, username and host only. `fill-login!` re-reads `held` from `sand-browser activity`, re-checks the item's host against the open pages, then types through the guest script. Errors never carry bw output or the secret. Routes `POST /api/browser-logins` and `POST /api/browser-fill-login` sit behind the dashboard write guard (header and Origin). Viewer: a Fill login button next to Type while Onur has control.
- Tests: 4 new deftests in `sandbox_browser_test.clj` (host matching, no password in the listing, refused unless held, refused for a site not open, no secret in any error). Ops tests 176/176.
- Live check on the Mini: the routes answer; not held gives "Take control first"; without the dashboard header gives 403. Listing logins fails with "Bitwarden could not answer … Run `secrets unlock`": the stored session in `~/.config/secrets/bw-session` is stale (`bw status` says locked).

### 2026-11-20 — First real use (dwca, Google sign-in) and the fix

Onur unlocked Bitwarden and tried it in `dwca`: the listing worked (40 logins for accounts.google.com), but the fill typed username, Tab, password on every page, so Google's password step got the username. Now `sand-browser focus` reports the focused field on the tab on screen (Chrome's `/json/list` is most-recently-activated first; over CDP every tab reports focus) and Ops chooses what to type (`fill-mode`): password boxes (type, autocomplete or name, so also with Show password) get the password; username/email fields get username + Tab + password only if the page shows a password field, else the username alone; nothing focused asks Onur to click a field. Viewer says what was typed and, after a username-only step, to Fill login again on the password page. Smoke: "fill login one step at a time (two-step sign-ins) -> ok". Ops tests 177/177.

## Waiting on Onur

- Bitwarden is unlocked (2026-11-20). Confirm one real two-step Google sign-in in `dwca` works with the fix: Fill login on the email step, then again on the password step.
- Note: the Bitwarden session file is readable by any process running as the Mini's user, agents included; Fill login adds no new exposure, but the boundary is the file, not Ops.

