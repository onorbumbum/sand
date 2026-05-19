#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
NAME="sand-run-$(date +%H%M%S)"
LOG="docs/validation/run-opaque-workload-commands/run-$(date +%Y%m%d-%H%M%S).log"
TMP_DIR="$(mktemp -d)"

exec > >(tee "$LOG") 2>&1

run() {
  printf '\n$'
  printf ' %q' "$@"
  printf '\n'
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
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

printf 'name=%s\nlog=%s\n' "$NAME" "$LOG"
run swift build || exit 1
cleanup
TMP_DIR="$(mktemp -d)"
trap cleanup EXIT

run .build/debug/sand create "$NAME" --cpus 2 --memory 1GB || exit 1
run .build/debug/sand "$NAME" status || exit 1

ARG_OUT="$TMP_DIR/args.json"
run_sh ".build/debug/sand '$NAME' run python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' --workload-flag -- literal 'two words' > '$ARG_OUT'" || exit 1
run_sh "test \"\$(cat '$ARG_OUT')\" = '[\"--workload-flag\", \"--\", \"literal\", \"two words\"]'" || exit 1
run .build/debug/sand "$NAME" status || exit 1

REDIRECT_OUT="$TMP_DIR/redirect.txt"
run_sh ".build/debug/sand '$NAME' run printf 'redirect-ok\\n' > '$REDIRECT_OUT'" || exit 1
run_sh "test \"\$(cat '$REDIRECT_OUT')\" = 'redirect-ok'" || exit 1

TTY_LOG="$TMP_DIR/tty.log"
printf '\n$ script -q %q .build/debug/sand %q run /bin/sh -lc %q\n' "$TTY_LOG" "$NAME" 'test -t 0 && test -t 1 && echo TTY_OK'
script -q "$TTY_LOG" .build/debug/sand "$NAME" run /bin/sh -lc 'test -t 0 && test -t 1 && echo TTY_OK'
status=$?
printf '[exit %s]\n' "$status"
cat "$TTY_LOG"
if [ "$status" -ne 0 ] || ! grep -q 'TTY_OK' "$TTY_LOG"; then exit 1; fi

printf '\n$ .build/debug/sand %q run definitely-not-installed-sand-006\n' "$NAME"
.build/debug/sand "$NAME" run definitely-not-installed-sand-006
status=$?
printf '[exit %s]\n' "$status"
if [ "$status" -eq 0 ]; then exit 1; fi

run .build/debug/sand delete "$NAME" --force || exit 1
trap - EXIT
rm -rf "$TMP_DIR"
printf '\nVALIDATION_PASS name=%s log=%s\n' "$NAME" "$LOG"
