# Developer-Ready Sandbox Image

Default image used by `sand create`:

```bash
sand/developer-ready:ubuntu-lts
```

Build it with the Apple `container` backend:

```bash
./scripts/build-developer-ready-image.sh
```

Smoke-check a real Sandbox Guest launched from the image:

```bash
./scripts/smoke-developer-ready-image.sh
```

Override inputs when needed:

```bash
PI_CLI_VERSION=0.73.1 \
SAND_DEVELOPER_READY_IMAGE=sand/developer-ready:ubuntu-lts \
./scripts/build-developer-ready-image.sh
```

The image is based on Ubuntu 24.04 LTS, creates the non-root `sandbox` user, grants passwordless sudo, sets `/workspace` as the default workdir, and includes the default developer/Pi toolset.
