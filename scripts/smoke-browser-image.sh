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
  DISPLAY=:99 xrandr | grep -q "VNC-0 connected" && echo "resizable VNC display -> ok"
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
  sand-browser activity > /tmp/activity.json
  python3 -c "
import json; a = json.load(open(\"/tmp/activity.json\"))
assert a[\"held\"] is False, a
assert a[\"last\"][\"command\"] == \"eval\", a
assert any(t[\"url\"].startswith(\"http://127.0.0.1:8765\") for t in a[\"tabs\"]), a
"
  echo "activity reports the last agent action -> ok"
  touch /tmp/sand-browser-held
  set +e
  sand-browser open http://127.0.0.1:8765/elsewhere >/tmp/held.out 2>&1; held_exit=$?
  set -e
  test "$held_exit" = 75 && grep -q "Onur has control" /tmp/held.out
  sand-browser tabs | grep -q "127.0.0.1:8765/$"
  rm -f /tmp/sand-browser-held
  echo "held browser refuses agent actions -> ok"
  mkdir -p /tmp/dl && echo "invoice 42" > /tmp/dl/invoice.txt
  (cd /tmp/dl && nohup python3 -m http.server 8766 --bind 127.0.0.1 >/dev/null 2>&1 &)
  sleep 1
  sand-browser open http://127.0.0.1:8766/ >/dev/null
  sand-browser eval "document.body.innerHTML = \"<a id=d href=/invoice.txt download>get</a>\"" >/dev/null
  sand-browser click "#d" | grep -q "downloaded: /state/sandbox/Downloads/invoice.txt"
  sand-browser click "#d" | grep -q "downloaded: /state/sandbox/Downloads/invoice (2).txt"
  test "$(sand-browser download-get invoice.txt)" = "invoice 42"
  sand-browser downloads --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert [x[\"name\"] for x in d][:2] == [\"invoice (2).txt\", \"invoice.txt\"] or sorted(x[\"name\"] for x in d) == [\"invoice (2).txt\", \"invoice.txt\"], d"
  if sand-browser download-get ../../etc/passwd >/dev/null 2>&1; then echo "download-get must refuse paths" >&2; exit 1; fi
  sand-browser download-delete "invoice (2).txt"
  test ! -e "/state/sandbox/Downloads/invoice (2).txt"
  test -L "$HOME/Downloads"
  sand-browser download-open invoice.txt
  sleep 2
  sand-browser tabs | grep -q "file:///state/sandbox/Downloads/invoice.txt"
  sand-browser close >/dev/null
  echo "downloads open in the sandbox Chromium -> ok"
  sand-browser open http://127.0.0.1:8765/ >/dev/null
  echo "agent downloads are kept -> ok"
  printf "photo bytes" | sand-browser upload-put "post photo.jpg" | grep -q "^uploaded: /state/sandbox/Uploads/post photo.jpg$"
  sand-browser uploads | grep -q "post photo.jpg"
  sand-browser eval "document.body.innerHTML = \"<input type=file id=f><button id=b>Add photo</button><input type=file id=hidden style=display:none>\"; document.getElementById(\"b\").onclick = () => document.getElementById(\"hidden\").click()" >/dev/null
  sand-browser upload "#f" "post photo.jpg" >/dev/null
  test "$(sand-browser eval "document.getElementById(\"f\").files[0].text()")" = "\"photo bytes\""
  sand-browser upload "#b" "post photo.jpg" >/dev/null
  test "$(sand-browser eval "document.getElementById(\"hidden\").files[0].name")" = "\"post photo.jpg\""
  test -L "$HOME/Uploads"
  sand-browser open http://127.0.0.1:8765/ >/dev/null
  echo "uploads reach the page -> ok"
  ldconfig -p | grep -q "libgtk-3.so.0"
  echo "file picker available -> ok"
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
  sand-browser tabs | grep -q "127.0.0.1:8765" || { echo "open tab not restored after restart" >&2; exit 1; }
  echo "tabs come back after restart -> ok"
  (cd /tmp && nohup python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &)
  sleep 1
  sand-browser open http://127.0.0.1:8765/ >/dev/null
  sand-browser eval "document.cookie" | grep -q sandlogin=yes || { echo "sign-in cookie lost across stop/start" >&2; exit 1; }
  echo "cookies survive stop/start -> ok"
  sand-browser downloads | grep -q "invoice.txt"
  echo "downloads survive a restart -> ok"
'
echo "live view after restart -> ok"
echo "browser image smoke passed"
