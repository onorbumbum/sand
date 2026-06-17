#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LOG="$ROOT/docs/validation/shared-folder-lifecycle-policy/run-$(date +%Y%m%d-%H%M%S).log"
NAME="sand-af-$(date +%H%M%S)"
HOST_ROOT="/tmp/sand-shared-folder-$NAME"
RW_DIR="$HOST_ROOT/rw"
RO_DIR="$HOST_ROOT/ro"
EXTRA_DIR="$HOST_ROOT/extra"
CHILD_LINK="$HOST_ROOT/rw-child-link"
SAND="$ROOT/.build/debug/sand"

mkdir -p "$(dirname "$LOG")"
exec > >(tee "$LOG") 2>&1

step() { printf '\n\n### %s\n' "$1"; }
run() { printf '\n$ %s\n' "$*"; "$@"; local status=$?; printf '[exit %s]\n' "$status"; return "$status"; }
run_sh() { printf '\n$ %s\n' "$*"; bash -lc "$*"; local status=$?; printf '[exit %s]\n' "$status"; return "$status"; }

cleanup() {
  container delete --force "$NAME" >/dev/null 2>&1 || true
  container volume delete "sand-state-$NAME" >/dev/null 2>&1 || true
  rm -rf "$HOST_ROOT"
  rm -f "$HOME/.sand/specs/$NAME.yaml"
}
trap cleanup EXIT

step "Build sand and prepare host folders"
run swift build --package-path "$ROOT"
cleanup
run mkdir -p "$RW_DIR/subdir" "$RO_DIR" "$EXTRA_DIR"
run_sh "echo host-original > '$RW_DIR/host-owned.txt'"
run_sh "echo readonly-host > '$RO_DIR/read-only-host.txt'"
run ln -s "$RW_DIR/subdir" "$CHILD_LINK"

step "Create stopped Sandbox VM and add read-write folder with default Guest Path"
run "$SAND" create "$NAME" --cpus 2 --memory 1GB
run "$SAND" folders add "$NAME" "$RW_DIR" rw
run "$SAND" folders list "$NAME"
run_sh "grep -F '$RW_DIR' '$HOME/.sand/specs/$NAME.yaml'"
run_sh "grep -F 'guestPath: /workspace/rw' '$HOME/.sand/specs/$NAME.yaml'"
run_sh "grep -F 'accessMode: read-write' '$HOME/.sand/specs/$NAME.yaml'"

step "Idempotently update existing host folder Guest Path and add read-only folder"
run "$SAND" folders add "$NAME" "$RW_DIR" read-write --as /code
run "$SAND" folders add "$NAME" "$RO_DIR" ro --as /reference
run "$SAND" folders list "$NAME"
run_sh "grep -F 'guestPath: /code' '$HOME/.sand/specs/$NAME.yaml'"
run_sh "grep -F 'accessMode: read-only' '$HOME/.sand/specs/$NAME.yaml'"

step "Reject duplicate Guest Paths, overlapping host folders, and symlink realpath overlap"
if "$SAND" folders add "$NAME" "$EXTRA_DIR" rw --as /code; then
  echo "duplicate Guest Path was accepted" >&2
  exit 1
else
  echo "duplicate Guest Path rejected"
fi
if "$SAND" folders add "$NAME" "$RW_DIR/subdir" rw; then
  echo "overlapping host folder was accepted" >&2
  exit 1
else
  echo "overlapping host folder rejected"
fi
if "$SAND" folders add "$NAME" "$CHILD_LINK" rw; then
  echo "symlink overlap was accepted" >&2
  exit 1
else
  echo "symlink realpath overlap rejected"
fi

step "Remove and re-add an Shared Folder while stopped"
run "$SAND" folders remove "$NAME" "$RO_DIR"
run "$SAND" folders list "$NAME"
if grep -F '/reference' "$HOME/.sand/specs/$NAME.yaml"; then
  echo "removed read-only folder still present in spec" >&2
  exit 1
fi
run "$SAND" folders add "$NAME" "$RO_DIR" read-only --as /reference

step "Real read-write/read-only behavior and Host-Safe File Ownership"
run "$SAND" "$NAME" start
run "$SAND" "$NAME" run bash -lc 'echo guest-created > /code/guest-created.txt && echo guest-modified >> /code/host-owned.txt && cat /code/guest-created.txt /code/host-owned.txt'
run ls -lna "$RW_DIR"
HOST_UID="$(id -u)"
run_sh "test \"\$(stat -f '%u' '$RW_DIR/guest-created.txt')\" = '$HOST_UID'"
run_sh "test \"\$(stat -f '%u' '$RW_DIR/host-owned.txt')\" = '$HOST_UID'"
if "$SAND" "$NAME" run bash -lc 'echo should-fail > /reference/blocked.txt'; then
  echo "read-only write unexpectedly succeeded" >&2
  exit 1
else
  echo "read-only write rejected"
fi
run_sh "test ! -e '$RO_DIR/blocked.txt'"

step "Running config changes ask before interrupting"
if printf 'n\n' | "$SAND" folders add "$NAME" "$EXTRA_DIR" rw --as /extra; then
  echo "cancelled running config change unexpectedly succeeded" >&2
  exit 1
else
  echo "running config change prompted and cancelled"
fi
if grep -F '/extra' "$HOME/.sand/specs/$NAME.yaml"; then
  echo "cancelled running config change mutated spec" >&2
  exit 1
fi

step "Cleanup through sand delete removes runtime metadata"
run "$SAND" "$NAME" stop
run "$SAND" delete "$NAME" --force
run_sh "test ! -e '$HOME/.sand/specs/$NAME.yaml'"
run_sh "test \"$(container inspect '$NAME' 2>/dev/null || true)\" = '[]'"
trap - EXIT
rm -rf "$HOST_ROOT"

echo "Validation completed successfully. Log: $LOG"
