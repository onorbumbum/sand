#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
NAME="sand-tdd-$(date +%H%M%S)"
LOG="docs/validation/start-stop-delete-guest-state/run-$(date +%Y%m%d-%H%M%S).log"

exec > >(tee "$LOG") 2>&1

run() {
  printf '\n$ %s\n' "$*"
  "$@"
  local status=$?
  printf '[exit %s]\n' "$status"
  return "$status"
}

run_sh() {
  printf '\n$ %s\n' "$*"
  bash -lc "$*"
  local status=$?
  printf '[exit %s]\n' "$status"
  return "$status"
}

cleanup() {
  .build/debug/sand delete "$NAME" --force >/dev/null 2>&1 || true
}
trap cleanup EXIT

printf 'name=%s\nlog=%s\n' "$NAME" "$LOG"
run swift build || exit 1
cleanup

run .build/debug/sand create "$NAME" --cpus 2 --memory 1GB || exit 1
run .build/debug/sand "$NAME" start || exit 1
run .build/debug/sand "$NAME" status || exit 1
run .build/debug/sand "$NAME" run /bin/sh -lc 'echo marker-005 > /tmp/sand-marker-005 && cat /tmp/sand-marker-005' || exit 1
run .build/debug/sand "$NAME" stop || exit 1
run .build/debug/sand "$NAME" status || exit 1
run .build/debug/sand "$NAME" start || exit 1
run .build/debug/sand "$NAME" run /bin/sh -lc 'cat /tmp/sand-marker-005 && test "$(cat /tmp/sand-marker-005)" = marker-005' || exit 1

printf '\n$ printf no | .build/debug/sand delete %s\n' "$NAME"
printf 'no\n' | .build/debug/sand delete "$NAME"
status=$?
printf '[exit %s]\n' "$status"
if [ "$status" -eq 0 ]; then exit 1; fi

run test -f "$HOME/.sand/specs/$NAME.yaml" || exit 1
run container inspect "$NAME" || exit 1
run .build/debug/sand delete "$NAME" --force || exit 1
run_sh "test ! -f '$HOME/.sand/specs/$NAME.yaml'" || exit 1
run_sh "test \"\$(container inspect '$NAME')\" = '[]'" || exit 1

trap - EXIT
printf '\nVALIDATION_PASS name=%s log=%s\n' "$NAME" "$LOG"
