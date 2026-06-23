# Tart Backend Validation Spike

Date: 2026-06-22 PDT  
Host: Apple Silicon (`arm64`), macOS 26.3  
Tart: 2.32.1  
Image: `ghcr.io/cirruslabs/macos-sequoia-xcode:latest`  
VM names used: `sand-tart-validation-slice1`, `sand-tart-validation-cap2`, `sand-tart-validation-cap3`, `sand-tart-validation-cap4`  
Cleanup: all validation VMs deleted after the run.

Raw evidence:

- `raw-slice1-pane-capture.txt` — initial clone/key session transcript capture.
- `raw-manual-20260622.log` — manual continuation with exact commands and command output.
- `remote-shared-xcode-probe.sh` — guest-side probe used for Shared Folder, read-only, symlink, and Xcode build validation.
- `tart-run-sand-tart-validation-cap3-cap.log` / `tart-run-sand-tart-validation-cap4-cap.log` — concurrent-cap failure messages.
- `host-shares/run-20260622-fixed/` — minimal host-side Swift package used for the Xcode build probe.

## Verdict

**PASS — Tart satisfies the hard macOS Sandbox VM backend requirements. Proceed with the Tart CLI backend.**

The documented fallback, in-process Virtualization Framework, is not needed for this spike.

## Requirement verdicts

| Requirement | Verdict | Evidence |
|---|---:|---|
| Frictionless non-interactive session: clone prebuilt image, inject generated SSH key, connect with zero username/password prompt | PASS | `tart clone ghcr.io/cirruslabs/macos-sequoia-xcode:latest sand-tart-validation-slice1`; generated Ed25519 key; `tart exec ... append public key`; `ssh -i <generated-key> -o BatchMode=yes -o PasswordAuthentication=no admin@192.168.65.2 'whoami; pwd; sw_vers -productVersion'` returned `admin`, `/Users/admin`, `15.7.3`. |
| Guest Path symlink survives a real Xcode build with DerivedData | PASS | Guest symlink: `~/workspace/TartSymlinkProbe -> /Volumes/My Shared Files/rw/TartSymlinkProbe`; `xcodebuild -scheme TartSymlinkProbe -derivedDataPath ~/DerivedDataTartProbe -destination generic/platform=macOS build` returned `** BUILD SUCCEEDED **`; `DERIVED_DATA_OK`; built binary printed `Tart symlink probe`. |
| Host-Safe File Ownership | PASS | Guest-created file through rw share appeared on host as `-rw-r--r-- 1 onorbumbum staff ... guest-created.txt`; host appended and deleted it without sudo: `HOST_EDIT_DELETE_OK`. |
| Read-write and read-only mounts honored | PASS | Guest write through rw share succeeded. Guest write to `/Volumes/My Shared Files/ro/guest-should-fail.txt` failed with `operation not permitted`; host confirmed `RO_HOST_NO_FILE`. |
| Host-only networking | PASS | Running VM SSH reachable from Host Mac via `tart ip` (`192.168.65.2`) and injected key. Route used private host bridge `bridge101`; `ifconfig bridge101` showed member `vmenet1 flags=...<PRIVATE,VIRTIO>`; `lsof -nP -iTCP -sTCP:LISTEN` showed no Tart SSH/VNC listener on host LAN ports. No Tart port forwarding or bridged networking was used. |
| Resource defaults sane: 4 CPU / 16GB completes real Xcode build | PASS | `tart set sand-tart-validation-slice1 --cpu 4 --memory 16384`; Xcode 26.4.1 build completed in `real 12.64` seconds. |
| Concurrent-VM cap confirmed empirically | PASS | With two macOS VMs running (`sand-tart-validation-slice1`, `sand-tart-validation-cap2`), the third and fourth boot attempts failed: `The number of VMs exceeds the system limit (other running VMs: sand-tart-validation-cap2, sand-tart-validation-slice1)`. Effective cap observed: **2 concurrent macOS VMs**. |

## Important observations

- First pull of the Cirrus Xcode image downloaded a 64.6 GB compressed disk and took about 21 minutes. Subsequent local Tart clones were copy-on-write and effectively immediate.
- `tart ip` can time out if called too early during boot; waiting until SSH accepts connections avoids a false failure.
- When composing `--dir` arguments from zsh variables, brace variables before suffixes: `"ro:${RO}:ro"`. Unbraced `$RO:ro` is parsed by zsh as a parameter modifier and produces an invalid path.
- Tart's `--dir` with named shares exposes macOS guest paths under `/Volumes/My Shared Files/<name>`, matching the backend-managed symlink design.
