# Apple `container` Backend Validation Spike

Date: 2026-05-18 22:09 local

Conclusion: **PASS — proceed with Apple `container` CLI as the first Sandbox Backend.**

Full raw evidence: `docs/validation/apple-container-backend/run-20260518-220950.log`

Validation harness: `docs/validation/apple-container-backend/validate.sh`

Validation image definition: `docs/validation/apple-container-backend/Dockerfile`

## Environment

- Apple `container` CLI: `container CLI version 0.12.3 (build: release, commit: f989901)`
- Backend service status: `running`
- Validation image: `sand-validation-dev:latest`
- Runtime name: `sand-validation-spike`
- Guest State volume: `sand-validation-state`
- Host test root: `/tmp/sand-backend-validation`

## Hard requirement results

| Requirement | Result | Evidence summary |
|---|---:|---|
| Persistent Guest State survives stop/start | PASS | Wrote `/state/sandbox/persistent.txt`, ran `container stop sand-validation-spike`, `container start sand-validation-spike`, then read `before-stop` from the same path. |
| Read-write Shared Folders work | PASS | Mounted `/tmp/sand-backend-validation/rw` at `/workspace/rw`; Sandbox User wrote `guest-created.txt` and modified `host-owned.txt`. |
| Read-only Shared Folders block writes | PASS | Mounted `/tmp/sand-backend-validation/ro` at `/workspace/ro,readonly`; write failed with `Read-only file system`; host had no `blocked.txt`. |
| Host-Safe File Ownership for created files | PASS | Host `stat -f '%u' /tmp/sand-backend-validation/rw/guest-created.txt` returned host UID `501`. |
| Host-Safe File Ownership for modified files | PASS | Host `stat -f '%u' /tmp/sand-backend-validation/rw/host-owned.txt` returned host UID `501` after guest modification. |
| Interactive Sandbox Session as non-root Sandbox User | PASS | `container exec --tty --user sandbox --workdir /workspace sand-validation-spike bash -lc 'tty; whoami; pwd'` output `/dev/pts/0`, `sandbox`, `/workspace`. |
| Passwordless sudo inside Sandbox Guest | PASS | `container exec --user sandbox sand-validation-spike bash -lc 'sudo -n whoami'` output `root`. |
| Multiple Sandbox Sessions run concurrently | PASS | Two detached exec sessions slept concurrently; `pgrep -a sleep` showed init sleep plus two session sleeps; both wrote completion files. |
| Runtime recreation preserves Guest State | PASS | Deleted runtime with `container delete --force`; recreated runtime with same volume; `/state/sandbox/persistent.txt`, `session-one.txt`, and `session-two.txt` persisted. |
| Runtime recreation preserves Shared Folder behavior | PASS | Recreated runtime with same rw/ro mounts; rw modification succeeded; ro write still failed with `Read-only file system`. |
| Working Directory Mapping can start sessions inside mounted folders | PASS | Executed with `--workdir /workspace/rw/subdir`; `pwd` output `/workspace/rw/subdir`; wrote `mapped.txt` visible on Host Mac. |
| Outbound-Only Networking for package/API access | PASS | `curl -fsSL https://example.com >/tmp/example.html` succeeded inside the Sandbox Guest. |
| Backend service behavior / auto-start possibility | PASS | `container system status` showed `running`; idempotent `container system start` exited `0`, so `sand` can call it before backend operations. |
| Stop/start preserves Guest State | PASS | Same evidence as persistent Guest State stop/start check. |
| Developer-Ready Sandbox Image feasibility | PASS | `container build` built an Ubuntu 24.04 image with git, curl, sudo, ssh, Python 3, npm/node, tmux, ripgrep, gcc, and make. Smoke test found each command on PATH. |
| Pi CLI path / split remaining image work | PASS with follow-up | `npm view @mariozechner/pi-coding-agent version` returned `0.73.1`, proving network/package path. Baking and pinning Pi CLI belongs in `issues/sand/002-developer-ready-sandbox-image.md`. |
| Inbound networking / port publishing not needed for v1 | PASS | All validation used default outbound network only. `container inspect` showed `publishedPorts: []` and `publishedSockets: []`. No product requirement in this spike needed `--publish`. |

## Exact commands of interest

```bash
container --version
container system status
container system start
container build --progress plain -t sand-validation-dev:latest docs/validation/apple-container-backend
container volume create sand-validation-state
container run --name sand-validation-spike --detach --cpus 4 --memory 8G \
  --volume sand-validation-state:/state \
  --mount type=bind,source=/tmp/sand-backend-validation/rw,target=/workspace/rw \
  --mount type=bind,source=/tmp/sand-backend-validation/ro,target=/workspace/ro,readonly \
  sand-validation-dev:latest sleep 10000
container exec --tty --user sandbox --workdir /workspace sand-validation-spike bash -lc 'tty; whoami; pwd'
container exec --user sandbox sand-validation-spike bash -lc 'sudo -n whoami'
container exec --user sandbox --workdir /workspace/rw sand-validation-spike bash -lc 'echo guest-created > guest-created.txt && echo guest-modified >> host-owned.txt && pwd'
container exec --user sandbox --workdir /workspace/ro sand-validation-spike bash -lc 'echo should-fail > blocked.txt'
container exec --user sandbox sand-validation-spike bash -lc 'echo before-stop > /state/sandbox/persistent.txt'
container stop sand-validation-spike
container start sand-validation-spike
container exec --detach --user sandbox sand-validation-spike bash -lc 'sleep 3; echo session-one > /state/sandbox/session-one.txt'
container exec --detach --user sandbox sand-validation-spike bash -lc 'sleep 3; echo session-two > /state/sandbox/session-two.txt'
container exec --user sandbox sand-validation-spike bash -lc 'curl -fsSL https://example.com >/tmp/example.html && test -s /tmp/example.html'
container delete --force sand-validation-spike
container run --name sand-validation-spike --detach --cpus 4 --memory 8G \
  --volume sand-validation-state:/state \
  --mount type=bind,source=/tmp/sand-backend-validation/rw,target=/workspace/rw \
  --mount type=bind,source=/tmp/sand-backend-validation/ro,target=/workspace/ro,readonly \
  sand-validation-dev:latest sleep 10000
```

## Backend decision

Apple `container` satisfies the hard backend requirements for v1 at spike depth. Continue with the Apple `container` CLI backend behind `SandboxBackend`.

No non-Apple fallback, hidden rsync, chmod-after-every-run, or fake backend path is introduced or needed.
