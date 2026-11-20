---
title: Retire Aslan Browser in favour of sand Browser Sandboxes
status: ready-for-agent
type: prd
category: migration
labels:
  - sand
  - browser-sandbox
  - aslan-browser
  - migration
created: 2026-11-20
---

## Problem Statement

Agents browse with **Aslan Browser**: a native macOS WKWebView app on the Host Mac, driven by the `aslan` CLI over a Unix socket. It works, and it has accumulated real value (17 playbooks, 43 site notes, a learn mode, Bitwarden-backed sign-in), but it has the shape this project exists to avoid:

- **One browser, every identity.** All clients' Google, Meta and LinkedIn sessions live in one app on Onur's Mac, next to his own. A mistaken or misled agent in one client's task can act in another client's account.
- **On the Host Mac.** Downloads, uploads and page script run in Onur's everyday environment, not behind a Sandbox VM boundary.
- **Not watchable from Ops.** Onur cannot see or take over what an agent is doing from the dashboard, the MacBook or the phone.
- **A second, bespoke stack to keep alive.** A Swift app built per machine (the Mini needed an ad hoc rebuild, 2026-11-12), its CLI links, and a release process.

sand **Browser Sandboxes** now cover the core of this (ADR 0002): a headed Chrome per client inside its own Sandbox VM; agents drive it with `sand-browser` over guest-only CDP; Onur watches, takes over (the agent pauses), types and pastes through Ops Live Browsers; sign-ins, tabs and files persist in Guest State; downloads and uploads cross the boundary only through two queues. Running both stacks indefinitely keeps every downside of Aslan and splits the knowledge.

## Solution

Retire Aslan Browser in vertical slices, measured, never in one switch:

1. **Measure first.** Record every `aslan` invocation (who, which command, which site) so retirement is decided by evidence, not memory.
2. **Close the capability gaps** that real playbooks use, in `sand-browser`: an accessibility tree with element refs, `type` for rich-text editors, `select`, key chords, scroll, waits, history, and tab management.
3. **Move the knowledge, not just the tool.** A `sand-browser` skill inherits Aslan's core rules, site notes and playbooks, rewritten to `sand-browser` commands and proven by running each playbook once in a Browser Sandbox.
4. **Give every client its browser.** A Browser Sandbox per client that has web work (named after the Client ID, which Ops already recognises), plus one general sandbox for non-client research. Onur signs in once per client in the Live View.
5. **Replace Bitwarden sign-in** with an Onur-initiated "Fill login" in the Live View, so passwords never pass through an agent.
6. **Switch every consumer** (Looker Studio fixer, web-search escalation, Pi's instructions, Google Business photo uploads), then run a shadow period with Aslan still installed but unused.
7. **Remove** the app, CLI links and skill once the usage log has shown no use for two weeks; archive the repos.

From Onur's perspective: client web work happens in that client's browser, visible in Ops; nothing about browsing runs on his Mac; and the same playbooks keep working.

## User Stories

1. As Onur, I want to know which Aslan commands, sites and playbooks are still used, so that retirement follows real usage.
2. As Onur, I want each client's web sign-ins to live only in that client's Browser Sandbox, so that one client's task cannot touch another client's accounts.
3. As Onur, I want to watch and take over any agent browsing from Ops, so that I am never blind to what an agent is doing on the web.
4. As an agent, I want to read a page as an accessibility tree with element refs and act on those refs, so that I can drive unfamiliar pages as reliably as with `aslan tree`.
5. As an agent, I want `type`, `select`, key chords, scroll, waits and history in `sand-browser`, so that existing playbooks (LinkedIn, Facebook, Google Business, Looker Studio) translate without workarounds.
6. As an agent, I want multiple named tabs, so that research across sites does not overwrite the page Onur left open.
7. As an agent, I want the site notes and playbooks Aslan accumulated, translated and verified, so that no hard-won knowledge is lost.
8. As Onur, I want to fill a saved login into a sandbox page from my password manager without the agent ever seeing it, so that sign-ins stay as easy as in Aslan.
9. As Onur, I want non-client browsing (research, my own accounts) in a separate general Browser Sandbox, so that client sandboxes stay single-purpose.
10. As Onur, I want Aslan removed only after a quiet shadow period, so that nothing I rely on disappears unnoticed.
11. As Onur, I want the Mini to stay within memory while more clients get browsers, so that idle stop and the run limit keep live browsers to about three.

## Implementation Decisions

- **Measurement (slice 032).** A thin wrapper in front of the `aslan` CLI appends one JSON line per call (time, command, target host, calling skill or Worker if known) to `~/.local/state/aslan-browser/usage.jsonl`. No behaviour change. `toolshed ops`-style reading is unnecessary: a weekly `jq` summary is enough.
- **`sand-browser` parity (033–035).** Implemented in `images/browser/sand-browser` with Playwright over CDP, as today:
  - `tree` prints Playwright's AI-mode accessibility snapshot, `page.ariaSnapshot({ mode: 'ai' })`, which carries refs (`button "Save" [ref=e3]`); actions accept `@e3` and resolve it with Playwright's `aria-ref=e3` selector. Verified 2026-11-20 with Playwright 1.64 against the sandbox's Chrome 158 (click and fill by ref). The plain `ariaSnapshot()` and `{ ref: true }` print no refs. Refs are valid until the next navigation, matching Aslan's contract.
  - `type` uses keyboard input (contenteditable), `select` uses `selectOption`, `key` accepts chords (`Control+Shift+g`), `scroll`, `wait --idle|--load`, `back`/`forward`/`reload`, `open --wait`.
  - Named tabs: `tab-new <name> [url]`, `tab-use`, `tab-close`, `tabs` shows names. The default tab rule (newest) stays for compatibility.
  - Each new command records the last agent action, respects the held flag, and is covered by the browser smoke test.
- **Knowledge (036).** New skill `skills/sand-browser/` (SKILL.md, `knowledge/core.md`, `knowledge/sites/`, `knowledge/playbooks/`). Aslan's files are copied, then every command rewritten (`aslan nav` → `sand run <box> sand-browser open`, `aslan tree` → `… tree`, `aslan upload <file>` → `upload-put` + `upload`). A playbook is marked verified only after one real run in a Browser Sandbox; unverified playbooks say so at the top. Learn mode is not ported in v1 (see Out of Scope).
- **Browsers per client (037).** `sand create <client id lowercased> --browser`, the client folder shared read-write at `/workspace`. One general sandbox, `web`, for non-client work. Onur signs in per client in the Live View. Idle stop already stops client browsers after 10 idle minutes; the Mini sustains about three live browsers (0.7–0.9 GB each, 4 GB colima VM).
- **Sign-in (038).** The Live View gains "Fill login": Ops (on the Mini, where Bitwarden `bw` already serves secrets) lists matching vault items for the page's host; Onur picks one; Ops types username and password into the focused fields via VNC key events. The agent never receives the secret; `sand-browser` cannot read it except from the page, same as any typed text. Decision needed: whether a Bitwarden session on the Mini is acceptable, or Fill login reads from the MacBook's browser instead (copy/paste already works).
- **Consumers (039).** `looker-studio-report-fixer` scripts move from `aslan eval/key/tree` to `sand-browser eval/key/tree` against the client's sandbox; `web-search` and `dotfiles/pi/AGENTS.md` escalate to the client's Browser Sandbox (or `web`); Google Business photo uploads use `upload-put` + `upload`.
- **Retirement (040).** Exit criteria: zero `aslan` calls in the usage log for 14 consecutive days, all consumers switched, the top-five playbooks by past use verified in sand. Then: remove the app and `aslan` links from both machines' bootstrap, delete the `aslan-browser` skill (its knowledge now lives in `sand-browser`), archive the `aslan-browser` and `aslan-browser-workspace` repos (read-only, not deleted), remove them from `dotfiles/repos.txt`.

## Testing Decisions

- Every `sand-browser` command gets a definition test (`BrowserImageDefinitionTests`) and a real check in `scripts/smoke-browser-image.sh`, as downloads, uploads and take-control have today. The smoke test is the contract: it runs against a real engine.
- Playbooks are verified by running them, not by review; each verified playbook records the date and Browser Sandbox it ran in.
- Ops changes (Fill login) follow the Live Browsers tests: pure functions for selection, a real WebSocket/VNC path test, and a check that the secret never appears in `/api/*` responses or logs.
- Retirement is gated on the usage log, not on a date.

## Out of Scope

- **Learn mode (recording Onur's actions into a playbook).** Valuable but separate; revisit after retirement with a CDP-based recorder in the Live View. Until then, Onur teaches by doing the task in the Live View while an agent watches the activity and writes the playbook.
- **Cookie import/export from Aslan.** Sign-ins are redone once per client in the Live View; copying cookies across browsers is fragile and would move every client's session into every sandbox.
- **Apple-silicon specifics.** On arm64 the image keeps Chrome for Testing (no Google Chrome arm64 Linux build): its file picker needs click-then-Open.
- **Deleting the Aslan repos.** They are archived, so the history and app remain recoverable.

## Further Notes

- `skills/aslan-browser` is a symlink to `~/_PROJECTS/aslan-browser/aslan-browser/skills/aslan-browser`: the skill and its knowledge are versioned in the Aslan repo, not the skills repo. Slice 036 copies the knowledge into the skills repo before slice 040 archives the Aslan repo.
- Inventory of Aslan users (2026-11-20): `skills/aslan-browser` (17 playbooks, 43 site notes, core rules, user prefs incl. Google Business photo uploads), `skills/looker-studio-report-fixer` (SKILL.md and `scripts/looker-ui.sh`: `nav`, `eval`, `key --meta --shift`, `tree`), `skills/web-search` (escalation), `dotfiles/pi/AGENTS.md` (escalation), `dotfiles/repos.txt` (two repos), the Mini's ad hoc Aslan build with PasswordManager. Historical mentions (`skills/release/notes.md`, `skills/create-skill/notes.md`, Ops Mini migration docs) stay as history.
- Usage summary (slice 032), on each machine: `aslan-usage --since 2026-11-20` (per command, host, caller, machine), or the one-liner `jq -r '[.cmd, .host // "-", .skill // .worker // .parent] | @tsv' ~/.local/state/aslan-browser/usage.jsonl | sort | uniq -c | sort -rn`. The wrapper is `dotfiles/bin/aslan-logged`, linked as `~/.local/bin/aslan`.
- Slices: 032 measure → 033–035 parity → 036 knowledge → 037 client browsers → 038 Fill login → 039 switch consumers → 040 retire. 033–035 can run in parallel; 036 needs 033–035; 039 needs 036–037; 040 needs everything plus the quiet period.
