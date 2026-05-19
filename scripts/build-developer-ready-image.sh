#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${SAND_DEVELOPER_READY_IMAGE:-sand/developer-ready:ubuntu-lts}"
PI_CLI_VERSION="${PI_CLI_VERSION:-0.73.1}"

container build \
  --progress plain \
  --build-arg "PI_CLI_VERSION=${PI_CLI_VERSION}" \
  -t "${IMAGE}" \
  "${ROOT}/images/developer-ready"
