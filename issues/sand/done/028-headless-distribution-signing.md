---
title: Sign a build for distribution headlessly inside a macOS Sandbox VM
status: done
type: issue
category: enhancement
labels:
  - ready-for-agent
  - afk
  - sand
  - sandbox-vm
  - macos
  - tart
  - signing
created: 2026-06-22
---

## Parent

- `issues/sand/prd-macos-sandbox-vm-tart-backend.md`

## What to build

Let the user code-sign builds for distribution (TestFlight, App Store, ad-hoc, enterprise) inside a macOS sandbox without any interactive Apple-ID login — the standard CI signing model. Inject the developer's certificate (`.p12`) and provisioning profile into the Sandbox Guest's keychain as a Signing Credentials Guest Secret (same shape as the SSH-key injection), so `xcodebuild` signs headlessly. The signing identity is never mounted from or shared with the Host Mac keychain. Building and running in the Simulator needs no signing or Apple ID at all. Apple-ID login for *automatic* signing management remains an optional one-time `gui` step (covered by the Setup Checklist slice), not a per-build gate.

Physical-device deploy/debug stays out of scope — Apple's Virtualization Framework has no USB passthrough for macOS guests.

## Acceptance criteria

- [x] A `.p12` certificate and provisioning profile can be injected into the guest keychain as a Guest Secret, not mounted from the host keychain.
- [x] `xcodebuild` signs a build for distribution headlessly, with no interactive Apple-ID login.
- [x] Building and running in the Simulator works with no signing and no Apple ID.
- [x] Injected Signing Credentials are treated as a Guest Secret stored in Guest State, never copied from or shared with the Host Mac.
- [x] Documentation states that physical-device deploy/debug is unsupported (no VF USB passthrough) and that `gui` gives VM desktop access, not host-device forwarding.
- [x] Acceptance is demonstrated against real Tart on Apple Silicon (a signed artifact is produced).

## Definition of Done

- [x] Deterministic tests are added/updated and `swift test` passes.
- [x] Backend-dependent acceptance evidence uses real Tart, not a fake.
- [x] Signing Credentials are handled as a Guest Secret; the host keychain is never mounted.
- [x] No interactive Apple-ID login is required for distribution signing.

## Progress

### 2026-06-23 09:19 PDT — Deterministic signing-credential path implemented

- Added `sand signing install <name> --certificate <p12> --certificate-password <password> --profile <mobileprovision> --keychain-password <password> [--keychain <name>]`.
- `LifecycleCoordinator` now rejects Linux guests, auto-starts stopped macOS guests, and delegates Signing Credentials injection through the macOS backend.
- `TartCLIBackend` injects the `.p12` and provisioning profile via guest-side base64 decode, creates/unlocks a guest keychain, imports the certificate for `codesign`/`xcodebuild`, sets the key partition list, and copies the provisioning profile into `~/Library/MobileDevice/Provisioning Profiles/` by UUID.
- Updated CLI docs/README to state that Signing Credentials are Guest Secrets, the Host Mac keychain is not mounted/shared, simulator builds need no signing or Apple ID, and physical-device deploy/debug is unsupported because macOS guests have no USB passthrough.
- Verification: `swift test` passed; `make check` passed.
- Not complete: live acceptance was not run because no real distribution `.p12`, provisioning profile, and Apple Silicon Tart sandbox were provided in this session; no signed artifact was produced.

### 2026-06-23 09:37 PDT — Secret-input hardening (env vars) added

Implemented the safe secret-input prerequisite the prior handoff required before live acceptance.

- `sand signing install` now accepts `--certificate-password-env <var>` and `--keychain-password-env <var>`, which read the password from the named environment variable instead of from a command-line argument (which would leak through shell history and the process list).
- The literal `--certificate-password`/`--keychain-password` flags still work, but exactly one source per secret is allowed: supplying both the literal and the `-env` form is rejected with `conflictingOptions`; an unset env var is rejected with `missingEnvironmentValue`.
- `CLICommandRouter` gained an injectable `readEnvironment` closure (defaults to `ProcessInfo.processInfo.environment`), mirroring the existing `readTextFile`/`readBinaryFile` seams.
- TDD slices (CLICommandRouterTests): certificate password from env, both passwords from env, conflict rejection, unset-env rejection.
- Docs: `signing` help text, generated `docs/cli-reference.md`, and the README signing example now show and recommend the `--*-password-env` flags; docs-input hashes refreshed.
- Verification: `swift test` (113 tests) and `make check` (tests + Documentation Freshness Gate) pass.
- Still not complete: live acceptance was not run — no real distribution `.p12`, provisioning profile, or Apple Silicon Tart sandbox was available in this session, so no signed artifact was produced.

### 2026-06-23 10:14 PDT — Live acceptance PASSED on real Tart (signed .ipa produced)

Ran the full live acceptance on Apple Silicon (this Mac) against real Tart `2.32.1` + the `ghcr.io/cirruslabs/macos-sequoia-xcode:latest` guest (Xcode 26.4.1), using a real **Apple Distribution** certificate and an **App Store** provisioning profile. The `sand` binary was built from this branch (`.build/release/sand`, `0.1.0-dev`).

Flow exercised:

- `sand create iosbox --os macos --from ghcr.io/cirruslabs/macos-sequoia-xcode:latest --disk 150GB` (the `--disk` override is required: the macOS default disk is 64GB but the image's virtual disk is 140GB, and `tart set --disk-size` can only grow — see "Follow-ups" below).
- `sand folders add iosbox <project> rw --as /Users/admin/workspace` to expose a minimal SwiftUI iOS app (bundle id `com.uzunu.sandsigntest`).
- `sand signing install iosbox --certificate dist.p12 --certificate-password-env P12_PASSWORD --profile App.mobileprovision --keychain-password-env KEYCHAIN_PASSWORD` — env-var secret input, auto-started the stopped guest, injected the credentials.
- `sand run iosbox xcodebuild archive ... CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=53T3AP3735 PROVISIONING_PROFILE_SPECIFIER="SandSign AppStore" CODE_SIGN_IDENTITY="Apple Distribution"`.
- `sand run iosbox xcodebuild -exportArchive -exportOptionsPlist ExportOptions.plist` (method `app-store`, `destination=export`, manual signing — no upload).

Evidence:

- `swift test` — 113 tests, 0 failures. `make check` — Documentation Freshness Gate passed.
- Credentials injected as a Guest Secret (guest-side base64 decode into a dedicated guest keychain). **Host Mac keychain was never mounted or shared.** No `.p12`/profile/password/`.ipa` committed (all kept under `~/Secrets/sand-signing` and `~/sandsigntest`, outside the repo).
- In-guest, no Apple-ID login: `security find-identity -v -p codesigning` →
  `1) … "Apple Distribution: Onur Uzunismail (53T3AP3735)"  1 valid identities found`.
- Provisioning profile installed in guest by UUID: `~/Library/MobileDevice/Provisioning Profiles/15ce3cb1-09da-4cc8-a159-5e7eeae07c11.mobileprovision`.
- `xcodebuild archive` → `** ARCHIVE SUCCEEDED **` (Signing Identity "Apple Distribution: Onur Uzunismail (53T3AP3735)", Provisioning Profile "SandSign AppStore").
- `xcodebuild -exportArchive` → `** EXPORT SUCCEEDED **`, produced `sandsigntest.ipa`.
- Artifact verified on host: `codesign --verify --verbose=2` → "valid on disk / satisfies its Designated Requirement"; `codesign -dvvv` → `Authority=Apple Distribution: Onur Uzunismail (53T3AP3735)` → Apple WWDR CA → Apple Root CA, `TeamIdentifier=53T3AP3735`; embedded profile "SandSign AppStore", app-id `53T3AP3735.com.uzunu.sandsigntest`, no `ProvisionedDevices` (App Store distribution profile).
- Simulator build proven separately: `xcodebuild build -sdk iphonesimulator … CODE_SIGNING_ALLOWED=NO` → `** BUILD SUCCEEDED **` (no signing, no Apple ID).

#### Follow-ups discovered during acceptance (not blockers; candidates for new issues)

1. **Keychain re-lock across sessions.** `sand signing install` unlocks the guest keychain inside its `tart exec` session, but a subsequent `sand run … xcodebuild` (a fresh SSH session) hit `errSecInternalComponent` at the `CodeSign` step until the keychain was explicitly re-unlocked in the signing session (`security unlock-keychain -p <kc-pw> <keychain>`). Acceptance succeeded with the explicit unlock. Consider having `sand` keep the injected keychain usable for headless `run` sessions (e.g. unlock-on-run, or `set-keychain-settings` without auto-lock) so users don't need the manual unlock. README now documents the unlock step.
2. **macOS default disk vs image disk.** Creating from the Xcode image with the default 64GB disk would fail because `tart set --disk-size` cannot shrink the image's 140GB virtual disk; `--disk 150GB` was required. Consider clamping the macOS default to be `>=` the source image disk, or surfacing a clearer error.

## Handoff: finish this properly

### 2026-06-23 09:37 PDT — Live acceptance plan for next agent (secret hardening DONE)

Secret-input hardening is complete (see the 09:37 progress entry). `sand signing install` now supports `--certificate-password-env <var>` and `--keychain-password-env <var>`, so passwords are read from environment variables and never appear in shell history or the process list. Use these env flags — not the literal `--certificate-password`/`--keychain-password` flags — with real credentials.

Only the live acceptance against real Tart on Apple Silicon remains.

Required real inputs:

- macOS Tart Sandbox VM with Xcode installed.
- Real distribution `.p12` certificate.
- Matching provisioning profile.
- Target Xcode app/project whose bundle ID/team matches the profile.
- `ExportOptions.plist` for the intended distribution method (`app-store`, `ad-hoc`, `enterprise`, etc.).

Suggested live acceptance flow:

```sh
# Create/start macOS sandbox if needed.
sand create iosbox --os macos --from ghcr.io/cirruslabs/macos-sequoia-xcode:latest
sand start iosbox

# Install credentials using env-var secret input (no passwords in shell history/process list).
export P12_PASSWORD=... KEYCHAIN_PASSWORD=...
sand signing install iosbox \
  --certificate /path/to/dist.p12 \
  --certificate-password-env P12_PASSWORD \
  --profile /path/to/App.mobileprovision \
  --keychain-password-env KEYCHAIN_PASSWORD

# Verify credentials exist inside the Sandbox Guest.
sand run iosbox security find-identity -v -p codesigning
sand run iosbox ls "$HOME/Library/MobileDevice/Provisioning Profiles"

# Build/archive with manual signing; fill real project values.
sand run iosbox xcodebuild archive \
  -project App.xcodeproj \
  -scheme App \
  -configuration Release \
  -archivePath /tmp/App.xcarchive \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=TEAMID \
  PROVISIONING_PROFILE_SPECIFIER="Profile Name"

# Export a signed artifact.
sand run iosbox xcodebuild -exportArchive \
  -archivePath /tmp/App.xcarchive \
  -exportPath /tmp/export \
  -exportOptionsPlist ExportOptions.plist
```

Evidence to record before closing:

- `swift test` and `make check` pass after secret-input hardening.
- `sand signing install ...` succeeds against real Tart with no Apple-ID login.
- `security find-identity -v -p codesigning` shows the imported signing identity in the guest.
- `xcodebuild archive` exits 0.
- `xcodebuild -exportArchive` exits 0.
- A signed `.ipa` or equivalent signed artifact exists under `/tmp/export` or another recorded path.
- `codesign`/embedded provisioning profile evidence confirms signing.
- No host keychain mount/share was used.
- No `.p12`, `.mobileprovision`, password, private key, or credential-bearing log is committed.

Only after this evidence exists:

- Mark the acceptance checklist complete.
- Mark Definition of Done complete.
- Move this issue to `issues/done/`.
- Commit code, docs, tests, issue move, and evidence notes.

## Remaining acceptance evidence

All complete — see the 2026-06-23 10:14 PDT live acceptance entry above.

- ~~Add safe secret-input support before using real credentials.~~ Done (env-var flags).
- ~~Run against real Tart on Apple Silicon with real distribution credentials.~~ Done.
- ~~Produce a signed archive/export with `xcodebuild` inside the macOS Sandbox VM without interactive Apple-ID login.~~ Done (signed `sandsigntest.ipa`).
- ~~Record the signed artifact evidence here, then mark the acceptance checklist complete.~~ Done.

## Blocked by

- `issues/sand/023-clone-and-shell-macos-sandbox.md` (done)
- ~~Real distribution `.p12`, provisioning profile, and a target app/project for live signing acceptance.~~ Provided and used in the 2026-06-23 live acceptance.
