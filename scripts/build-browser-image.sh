#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${SAND_BROWSER_IMAGE:-sand/browser:ubuntu-lts}"
BASE_IMAGE="${SAND_DEVELOPER_READY_IMAGE:-sand/developer-ready:ubuntu-lts}"
PLAYWRIGHT_VERSION="${PLAYWRIGHT_VERSION:-1.64.1}"
# shellcheck source=lib/container-engine.sh
source "${ROOT}/scripts/lib/container-engine.sh"

"${SAND_ENGINE}" build \
  --progress plain \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --build-arg "PLAYWRIGHT_VERSION=${PLAYWRIGHT_VERSION}" \
  -t "${IMAGE}" \
  "${ROOT}/images/browser"
