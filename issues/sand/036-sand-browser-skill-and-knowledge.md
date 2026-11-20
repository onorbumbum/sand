---
title: sand-browser skill: carry over Aslan's knowledge
status: in-progress
type: issue
category: migration
labels:
  - sand
  - aslan-browser-retirement
  - skills
  - knowledge
created: 2026-11-20
---

## Parent

- `issues/sand/prd-retire-aslan-browser.md`

## What to build

Create `skills/sand-browser/` (SKILL.md with the interactive driving protocol and knowledge-compilation rule from Aslan, adapted) and copy `knowledge/core.md`, `knowledge/sites/` and `knowledge/playbooks/` from `skills/aslan-browser/` (a symlink into the Aslan repo, so this copy is what keeps the knowledge after retirement; `knowledge/user.md` is gitignored there and must be copied by hand), rewriting every command to `sand run <box> sand-browser …`. Verify playbooks by running them; start with the five most used according to the 032 log.

## Acceptance criteria

- [x] Every Aslan site note and playbook exists in the new skill with `sand-browser` commands.
- [x] Each playbook states at the top whether it is verified in a Browser Sandbox (date, sandbox) or not yet.
- [ ] The five most-used playbooks (by the 032 log) are verified.
- [x] Aslan-only notes (WKWebView quirks, `https://`-only, ATS) are dropped, not copied.

## Blocked by

- `issues/sand/033-sand-browser-tree-and-refs.md`
- `issues/sand/034-sand-browser-interaction-parity.md`
- `issues/sand/035-sand-browser-named-tabs.md`

## Progress

### 2026-11-20 — Skill and knowledge ported; one playbook partly verified

`skills/sand-browser/`: new `SKILL.md` (critical rules for sandboxes: right box, own named tab, Onur signs in, exit 75; the interactive protocol and knowledge-compilation rule from Aslan; teaching by watching the Live View in place of learn mode), `knowledge/core.md` rewritten for `sand-browser` (WKWebView, ATS, launch and learn-mode notes dropped; refs, named tabs, uploads, covered elements, never-idle pages added), all 43 site notes and 17 playbooks copied and translated (172 commands mechanically, then about 70 lines by hand: uploads become `upload-put` + `upload`, `ASLAN_SESSION`/tab ids become named tabs, Nextdoor's native-panel AppleScript steps become one `upload` on the button). `knowledge/user.md` copied by hand and now committed. Aslan's `learnings/browser.md` (dated Aslan development notes) was not copied; its site items already live in the site notes. `sand-browser` gained `title`, `url`, `wait --for` and Aslan-style `eval` bodies so playbooks translate without rewriting their JS. The ops skill (4a) now says to load this skill.

Top five playbooks by past use (Pi and Claude sessions mentioning each file; the 032 log is too new to rank): distrokid-publish-album 142, linkedin-create-post 133, zoho-social-post-to-all 124, gmb-create-post 96, google-load-business-reviews 88.

- google-load-business-reviews: run 2026-11-20 in `web` (recreated on the new image with `sand apply web`). Steps 1–3, 6, 7 work; signed out, Google now shows a limited view (about 5 reviews), so steps 4–5 cannot be verified until Onur signs in. The playbook was fixed from the run (`--wait load` on Maps, the right scroll panel, sign-in prerequisite).
- The other four publish to real accounts (DistroKid, LinkedIn, Zoho Social, Google Business). They need the client's Browser Sandbox signed in (slice 037) and a real, approved piece of work to post; verify each on its next real task.

## Waiting on Onur

- Sign in to Google in Live Browsers → `web` (own account), then rerun google-load-business-reviews.
- Verify the four publishing playbooks on their next real tasks, in the client sandboxes from 037.

