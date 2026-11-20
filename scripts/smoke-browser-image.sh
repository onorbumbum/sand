#!/usr/bin/env bash
# Proves the browser image contract against a real engine:
#   - the noVNC live view answers on the Host Mac loopback publish
#   - Chromium's CDP answers inside the guest and is NOT reachable from the host
#   - an agent in the guest can drive the page with sand-browser
#   - the profile lives in Guest State
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${SAND_BROWSER_IMAGE:-sand/browser:ubuntu-lts}"
CONTAINER="${SAND_BROWSER_SMOKE_CONTAINER:-sand-browser-smoke}"
VIEW_PORT="${SAND_BROWSER_SMOKE_PORT:-6199}"
# shellcheck source=lib/container-engine.sh
source "${ROOT}/scripts/lib/container-engine.sh"

cleanup() {
  sand_engine_remove "${CONTAINER}"
}
trap cleanup EXIT
cleanup

shm=()
[ "${SAND_ENGINE}" = docker ] && shm=(--shm-size 1g)

"${SAND_ENGINE}" run \
  --name "${CONTAINER}" \
  --detach \
  --cpus 2 \
  --memory 2G \
  --publish "127.0.0.1:${VIEW_PORT}:6080" \
  "${shm[@]}" \
  "${IMAGE}" \
  /usr/local/bin/sand-browser-up >/dev/null

printf 'waiting for live view on 127.0.0.1:%s ' "${VIEW_PORT}"
for _ in $(seq 1 60); do
  curl -fsS "http://127.0.0.1:${VIEW_PORT}/vnc.html" >/dev/null 2>&1 && break
  printf '.'
  sleep 1
done
echo
curl -fsS "http://127.0.0.1:${VIEW_PORT}/vnc.html" | grep -qi novnc
echo "live view -> ok"

if curl -fsS --max-time 3 http://127.0.0.1:9222/json/version >/dev/null 2>&1; then
  echo "CDP is reachable from the Host Mac; it must stay guest-only" >&2
  exit 1
fi
echo "CDP not published to host -> ok"

"${SAND_ENGINE}" exec --user sandbox "${CONTAINER}" bash -lc '
  set -euo pipefail
  for _ in $(seq 1 60); do curl -fsS http://127.0.0.1:9222/json/version >/dev/null 2>&1 && break; sleep 1; done
  curl -fsS http://127.0.0.1:9222/json/version | grep -q "Browser"
  echo "CDP in guest -> ok"
  sand-browser open "data:text/html,<title>sand smoke</title><h1>hello from the browser sandbox</h1>"
  sand-browser text | grep -q "hello from the browser sandbox"
  echo "sand-browser drives the page -> ok"
  sand-browser screenshot /tmp/smoke.png >/dev/null
  test -s /tmp/smoke.png
  echo "screenshot -> ok"
  test -d /state/sandbox/chromium/Default
  echo "profile in Guest State -> ok"
  node -e "require(\"playwright\")" && echo "playwright importable -> ok"
  (cd /tmp && nohup python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &)
  sleep 1
  sand-browser open http://127.0.0.1:8765/ >/dev/null
  sand-browser eval "document.cookie = \"sandlogin=yes; max-age=86400; path=/\"" >/dev/null
'
# Stop/start keeps the container filesystem, like `sand stop` / `sand start`.
"${SAND_ENGINE}" stop "${CONTAINER}" >/dev/null
"${SAND_ENGINE}" start "${CONTAINER}" >/dev/null
for _ in $(seq 1 60); do
  curl -fsS "http://127.0.0.1:${VIEW_PORT}/vnc.html" >/dev/null 2>&1 && break
  sleep 1
done
curl -fsS "http://127.0.0.1:${VIEW_PORT}/vnc.html" | grep -qi novnc
"${SAND_ENGINE}" exec --user sandbox "${CONTAINER}" bash -lc '
  for _ in $(seq 1 60); do curl -fsS http://127.0.0.1:9222/json/version >/dev/null 2>&1 && break; sleep 1; done
  (cd /tmp && nohup python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &)
  sleep 1
  sand-browser open http://127.0.0.1:8765/ >/dev/null
  sand-browser eval "document.cookie" | grep -q sandlogin=yes || { echo "sign-in cookie lost across stop/start" >&2; exit 1; }
  echo "cookies survive stop/start -> ok"
'
echo "live view after restart -> ok"
echo "browser image smoke passed"
