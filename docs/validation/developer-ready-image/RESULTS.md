# Developer-Ready Sandbox Image Validation

Date: 2026-05-18 22:31 local

Conclusion: **PASS — `sand/developer-ready:ubuntu-lts` builds and a real Apple `container` Sandbox Guest passes the default toolset smoke check.**

Raw evidence: `docs/validation/developer-ready-image/run-20260518-223134.log`

Image definition: `images/developer-ready/Dockerfile`

Build script: `scripts/build-developer-ready-image.sh`

Smoke script: `scripts/smoke-developer-ready-image.sh`

## Image contract

- Base: `docker.io/library/ubuntu:24.04` (Ubuntu LTS)
- Tag: `sand/developer-ready:ubuntu-lts`
- Sandbox User: `sandbox`
- Default workdir: `/workspace`
- Passwordless sudo: `/etc/sudoers.d/sandbox`
- Pi CLI package: `@mariozechner/pi-coding-agent@0.73.1`
- Node source: NodeSource `node_22.x` because Pi CLI requires Node `>=20.6.0`

## Smoke result summary

| Check | Result | Evidence |
|---|---:|---|
| Image builds from Ubuntu LTS | PASS | `Successfully built sand/developer-ready:ubuntu-lts` |
| Real Sandbox Guest launches from image | PASS | `container run ... sand/developer-ready:ubuntu-lts sleep 10000` in smoke script exited 0 |
| Non-root Sandbox User | PASS | `whoami -> sandbox` |
| Default `/workspace` workdir | PASS | `pwd -> /workspace` |
| Passwordless sudo | PASS | `sudo -n whoami -> root` |
| git | PASS | `git version 2.43.0` |
| curl | PASS | `curl 8.5.0` |
| ca-certificates | PASS | TLS-backed curl command/version uses system certificates; package present in Dockerfile |
| sudo | PASS | `Sudo version 1.9.15p5` |
| openssh-client | PASS | `OpenSSH_9.6p1` |
| Python 3 | PASS | `Python 3.12.3` |
| Python venv/pip | PASS | `python3 -m venv /tmp/sand-venv`; `pip 24.0` |
| Node/npm | PASS | `node v22.22.2`; `npm 10.9.7` |
| tmux | PASS | `tmux 3.4` |
| ripgrep | PASS | `ripgrep 14.1.0` |
| build-essential | PASS | `gcc 13.3.0`; `GNU Make 4.3` |
| Pi CLI | PASS | `pi 0.73.1` |

## Exact commands

```bash
./scripts/build-developer-ready-image.sh
./scripts/smoke-developer-ready-image.sh
```

No fake or in-memory backend was used for acceptance evidence.
