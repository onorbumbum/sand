#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LOG_DIR="$ROOT/docs/validation/working-directory-mapping"
LOG="$LOG_DIR/run-$(date +%Y%m%d-%H%M%S).log"
NAME="sand-wd-$(date +%H%M%S)"
HOST_ROOT="/tmp/sand-working-directory-$NAME"
HOST_PROJECT="$HOST_ROOT/project"
HOST_NESTED="$HOST_PROJECT/src/module"
HOST_OUTSIDE="$HOST_ROOT/outside"
HOST_LINK="$HOST_ROOT/project-link"
SAND="$ROOT/.build/debug/sand"
SOCKET="sand-wd-validation"
SHELL_ALLOWED="sand009-shared"
SHELL_OUTSIDE="sand009-outside"

mkdir -p "$LOG_DIR"
exec > >(tee "$LOG") 2>&1

step() { printf '\n\n### %s\n' "$1"; }
run() { printf '\n$ %s\n' "$*"; "$@"; local status=$?; printf '[exit %s]\n' "$status"; return "$status"; }

cleanup() {
  tmux -L "$SOCKET" kill-session -t "$SHELL_ALLOWED" >/dev/null 2>&1 || true
  tmux -L "$SOCKET" kill-session -t "$SHELL_OUTSIDE" >/dev/null 2>&1 || true
  "$SAND" delete "$NAME" --force >/dev/null 2>&1 || true
  container delete --force "$NAME" >/dev/null 2>&1 || true
  container volume delete "sand-state-$NAME" >/dev/null 2>&1 || true
  rm -rf "$HOST_ROOT"
  rm -f "$HOME/.sand/specs/$NAME.yaml"
}
trap cleanup EXIT

capture_run() {
  local cwd="$1"
  local expected_stdout="$2"
  local expected_stderr_substring="${3:-}"
  local stdout_file="$HOST_ROOT/stdout.txt"
  local stderr_file="$HOST_ROOT/stderr.txt"

  printf '\n$ (cd %q && %q %q run pwd)\n' "$cwd" "$SAND" "$NAME"
  set +e
  (cd "$cwd" && "$SAND" "$NAME" run pwd >"$stdout_file" 2>"$stderr_file")
  local status=$?
  set -e
  printf '[exit %s]\n' "$status"
  printf -- '--- stdout ---\n%s\n' "$(cat "$stdout_file")"
  printf -- '--- stderr ---\n%s\n' "$(cat "$stderr_file")"

  if [[ "$status" -ne 0 ]]; then
    echo "run pwd failed from $cwd" >&2
    exit 1
  fi
  if [[ "$(cat "$stdout_file")" != "$expected_stdout" ]]; then
    echo "expected stdout '$expected_stdout' from $cwd" >&2
    exit 1
  fi
  if [[ -n "$expected_stderr_substring" ]]; then
    if ! grep -Fq "$expected_stderr_substring" "$stderr_file"; then
      echo "missing expected warning '$expected_stderr_substring' from $cwd" >&2
      exit 1
    fi
  elif [[ -s "$stderr_file" ]]; then
    echo "unexpected warning from mapped cwd $cwd" >&2
    exit 1
  fi
}

step "Build sand and prepare host directories"
run swift build --package-path "$ROOT"
cleanup
run mkdir -p "$HOST_NESTED" "$HOST_OUTSIDE"
run ln -s "$HOST_PROJECT" "$HOST_LINK"

step "Backend prerequisites"
run container --version
run container system status
run container image inspect sand/developer-ready:ubuntu-lts

step "Create Sandbox VM with one Shared Folder"
run "$SAND" create "$NAME" --cpus 2 --memory 1GB
run "$SAND" folders add "$NAME" "$HOST_PROJECT" rw --as /workspace/project
run "$SAND" folders list "$NAME"

step "run maps shared, nested, symlinked, and outside Host cwd paths"
capture_run "$HOST_PROJECT" "/workspace/project"
capture_run "$HOST_NESTED" "/workspace/project/src/module"
capture_run "$HOST_LINK/src/module" "/workspace/project/src/module"
capture_run "$HOST_OUTSIDE" "/workspace" "Current directory is not inside an Shared Folder; starting in /workspace."

step "shell uses the same mapping from inside an Shared Folder"
tmux -L "$SOCKET" new-session -d -s "$SHELL_ALLOWED" "cd '$HOST_NESTED' && '$SAND' '$NAME' shell; echo SHELL_EXIT:\$?; sleep 30"
sleep 3
tmux -L "$SOCKET" send-keys -t "$SHELL_ALLOWED" "pwd; exit" Enter
sleep 2
ALLOWED_CAPTURE="$(tmux -L "$SOCKET" capture-pane -t "$SHELL_ALLOWED" -p || true)"
printf '%s\n' "--- shared shell capture ---" "$ALLOWED_CAPTURE"
if ! grep -Fq "/workspace/project/src/module" <<<"$ALLOWED_CAPTURE"; then
  echo "shell did not start in mapped nested Guest Path" >&2
  exit 1
fi

step "shell warns and falls back from outside Shared Folders"
tmux -L "$SOCKET" new-session -d -s "$SHELL_OUTSIDE" "cd '$HOST_OUTSIDE' && '$SAND' '$NAME' shell; echo SHELL_EXIT:\$?; sleep 30"
sleep 3
tmux -L "$SOCKET" send-keys -t "$SHELL_OUTSIDE" "pwd; exit" Enter
sleep 2
OUTSIDE_CAPTURE="$(tmux -L "$SOCKET" capture-pane -t "$SHELL_OUTSIDE" -p || true)"
printf '%s\n' "--- outside shell capture ---" "$OUTSIDE_CAPTURE"
if ! grep -Fq "Current directory is not inside an Shared Folder; starting in /workspace." <<<"$OUTSIDE_CAPTURE"; then
  echo "shell outside Shared Folders did not warn" >&2
  exit 1
fi
if ! grep -Fq "/workspace" <<<"$OUTSIDE_CAPTURE"; then
  echo "shell outside Shared Folders did not start in fallback Guest Path" >&2
  exit 1
fi

step "Cleanup through sand delete"
run "$SAND" delete "$NAME" --force
trap - EXIT
rm -rf "$HOST_ROOT"

echo "Validation completed successfully. Log: $LOG"
