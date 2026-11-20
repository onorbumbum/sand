---
title: A Browser Sandbox for every client with web work
status: in-progress
type: issue
category: migration
labels:
  - sand
  - aslan-browser-retirement
  - operations
  - browser-sandbox
created: 2026-11-20
---

## Parent

- `issues/sand/prd-retire-aslan-browser.md`

## What to build

From the 032 log and Ops tasks, list clients whose work touches the web. For each: `sand create <client id lowercased> --browser`, share the client folder read-write at `/workspace`, and have Onur sign in to that client's accounts once in the Live View. Keep `web` as the general sandbox for non-client work. Confirm Worker briefs show the Browser section for each.

## Acceptance criteria

- [x] Each listed client has a Browser Sandbox named after its Client ID, with its folder shared.
- [ ] Onur has signed in to each client's accounts in its own sandbox; no client's sessions are in another's.
- [x] Live Browsers lists them; idle stop keeps at most about three running.

## Blocked by

- `issues/sand/032-measure-aslan-browser-use.md`

## Progress

### 2026-11-20 — Four client Browser Sandboxes created

Clients chosen with Onur from open Ops web work (DCC 20 tasks, WCM 8, DWCA 5, AGT 3; the 032 log was too new to rank): `sand create <id> --browser` then `sand folders add <id> ~/_SITES/<site> rw --as /workspace` for `dcc` (deepcleancrew.com), `wcm` (wecaremedicareplans.com), `dwca` (dutchwindowcleaningartist.com), `agt` (aguilar-team.com). Each was started once to check: `/workspace` lists the site repo and is writable, `sand-browser status` answers; then stopped. `GET /api/browsers` lists all four with their Client IDs, stopped; `web` stays the general sandbox (recreated on the new image the same day). Worker briefs show the Browser section for any client whose sandbox exists (`runner.clj` `browser-section`); the section now points to the sand-browser skill, `tree`/refs and named tabs.

### 2026-11-20 — agt flashed in the Live View: fixed

Onur saw `agt` flash at random. The sandbox's own screen was steady (40 s of X captures, no change); the Chrome log showed the New Tab page reloading four times a second while a second viewer was connected (20:46:40–20:47:09Z), which is what a screen resize does to it. Cause: noVNC measures the viewer area with `getBoundingClientRect`; a fractional area (Retina) never equals the whole-pixel sandbox screen, so it requested a resize about ten times a second, and two viewers of different sizes made the screen ping-pong. Reproduced headless in `web` (96 requests in 10 s); the viewer now offers whole pixels and the same run sends one (toolshed `c757049`). Same commit: `ops serve` clears stale held flags at startup, matching `sand-browser-up` clearing it when a sandbox starts. An already open Live View keeps the old code until it is reloaded.
Onur confirmed the `agt` Live View steady on his own screen after the fix (2026-11-20, 14:40).

### 2026-11-20 — agt signed in to Google

`agt` shows a signed-in Google account on google.com (account button, no Sign in link; checked 14:4x without reading which account). Other sites agt uses (Meta, LinkedIn) not checked.

## Waiting on Onur

- Sign in to each client's accounts once, in its own sandbox only: Ops → Live Browsers → `dcc`, `wcm`, `dwca` (`agt` has Google; add its other sites as needed) (Google Business / Google Ads / Meta / LinkedIn as each client uses them). Then tick the second criterion.

