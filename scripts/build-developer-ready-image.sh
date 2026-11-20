#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${SAND_DEVELOPER_READY_IMAGE:-sand/developer-ready:ubuntu-lts}"
PI_CLI_VERSION="${PI_CLI_VERSION:-0.73.1}"
# shellcheck source=lib/container-engine.sh
source "${ROOT}/scripts/lib/container-engine.sh"

"${SAND_ENGINE}" build \
  --progress plain \
  --build-arg "PI_CLI_VERSION=${PI_CLI_VERSION}" \
  -t "${IMAGE}" \
  "${ROOT}/images/developer-ready"
