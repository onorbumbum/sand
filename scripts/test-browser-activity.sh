#!/usr/bin/env bash
# Test the worktree CLI with the browser and Playwright from a local Sand image.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${SAND_BROWSER_IMAGE:-sand/browser:ubuntu-lts}"

# Do not pull, publish ports, mount guest state, or reuse a browser profile.
docker run --rm --pull never --network none --entrypoint node \
  --mount "type=bind,source=${ROOT}/images/browser/sand-browser,target=/tmp/sand-browser-under-test,readonly" \
  --mount "type=bind,source=${ROOT}/scripts/test-browser-activity.cjs,target=/tmp/test-browser-activity.cjs,readonly" \
  "${IMAGE}" /tmp/test-browser-activity.cjs /tmp/sand-browser-under-test
