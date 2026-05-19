#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SAND="${SAND_BINARY:-${ROOT}/.build/debug/sand}"
NAME="${SAND_VALIDATION_NAME:-sand007shell}"
SOCKET="sand-shell-validation"
SESSION_ONE="sand007-one"
SESSION_TWO="sand007-two"
LOG_DIR="${ROOT}/docs/validation/shell-sessions-sandbox-user"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/run-$(date +%Y%m%d-%H%M%S).log}"

mkdir -p "${LOG_DIR}"
exec > >(tee "${LOG_FILE}") 2>&1

log() {
  printf '\n## %s\n' "$*"
}

cleanup() {
  tmux -L "${SOCKET}" kill-session -t "${SESSION_ONE}" >/dev/null 2>&1 || true
  tmux -L "${SOCKET}" kill-session -t "${SESSION_TWO}" >/dev/null 2>&1 || true
  "${SAND}" delete "${NAME}" --force >/dev/null 2>&1 || true
}
trap cleanup EXIT

log "Build sand"
cd "${ROOT}"
swift build

log "Backend prerequisites"
container --version
container system status
container image inspect sand/developer-ready:ubuntu-lts >/dev/null

log "Clean existing validation sandbox"
cleanup

log "Create stopped Sandbox VM"
"${SAND}" create "${NAME}"
"${SAND}" "${NAME}" status

log "Open two real Sandbox Sessions concurrently"
tmux -L "${SOCKET}" new-session -d -s "${SESSION_ONE}" "cd '${ROOT}' && '${SAND}' '${NAME}' shell"
tmux -L "${SOCKET}" new-session -d -s "${SESSION_TWO}" "cd '${ROOT}' && '${SAND}' '${NAME}' shell"
sleep 3

log "Drive session one"
tmux -L "${SOCKET}" send-keys -t "${SESSION_ONE}" "printf 'SESSION_ONE user=%s sudo=%s tty=%s pwd=%s\\n' \"\$(whoami)\" \"\$(sudo -n whoami)\" \"\$(test -t 0 && echo yes || echo no)\" \"\$(pwd)\"" Enter
tmux -L "${SOCKET}" send-keys -t "${SESSION_ONE}" "sleep 8; echo SESSION_ONE_DONE" Enter

log "Drive session two while session one is still sleeping"
tmux -L "${SOCKET}" send-keys -t "${SESSION_TWO}" "printf 'SESSION_TWO user=%s sudo=%s tty=%s pwd=%s\\n' \"\$(whoami)\" \"\$(sudo -n whoami)\" \"\$(test -t 0 && echo yes || echo no)\" \"\$(pwd)\"" Enter
tmux -L "${SOCKET}" send-keys -t "${SESSION_TWO}" "echo SESSION_TWO_DONE" Enter
sleep 2

log "Capture concurrent session output before session one sleep completes"
ONE_BEFORE="$(tmux -L "${SOCKET}" capture-pane -t "${SESSION_ONE}" -p)"
TWO_BEFORE="$(tmux -L "${SOCKET}" capture-pane -t "${SESSION_TWO}" -p)"
printf '%s\n' "--- session one before ---" "${ONE_BEFORE}" "--- session two before ---" "${TWO_BEFORE}"

if ! grep -q 'SESSION_TWO_DONE' <<<"${TWO_BEFORE}"; then
  echo "Expected session two to complete while session one was still sleeping" >&2
  exit 1
fi
if grep -qx 'SESSION_ONE_DONE' <<<"${ONE_BEFORE}"; then
  echo "Session one finished too early; concurrency check did not observe overlap" >&2
  exit 1
fi

sleep 7
log "Capture final session output"
ONE_AFTER="$(tmux -L "${SOCKET}" capture-pane -t "${SESSION_ONE}" -p)"
TWO_AFTER="$(tmux -L "${SOCKET}" capture-pane -t "${SESSION_TWO}" -p)"
printf '%s\n' "--- session one after ---" "${ONE_AFTER}" "--- session two after ---" "${TWO_AFTER}"

for expected in \
  'SESSION_ONE user=sandbox sudo=root tty=yes' \
  'SESSION_TWO user=sandbox sudo=root tty=yes' \
  'SESSION_ONE_DONE' \
  'SESSION_TWO_DONE'
do
  if ! grep -q "${expected}" <<<"${ONE_AFTER}${TWO_AFTER}"; then
    echo "Missing expected output: ${expected}" >&2
    exit 1
  fi
done

if grep -Eiq 'login:|password:' <<<"${ONE_AFTER}${TWO_AFTER}"; then
  echo "Unexpected login/password prompt found" >&2
  exit 1
fi

log "Exit sessions"
tmux -L "${SOCKET}" send-keys -t "${SESSION_ONE}" "exit" Enter
tmux -L "${SOCKET}" send-keys -t "${SESSION_TWO}" "exit" Enter
sleep 1

log "Validation passed"
echo "Raw log: ${LOG_FILE}"
