#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
NAME="sand-pi-boundary-$(date +%H%M%S)"
LOG="docs/validation/pi-workload-credential-boundary/run-$(date +%Y%m%d-%H%M%S).log"
TMP_DIR="$(mktemp -d)"
INSPECT_OUT="$TMP_DIR/container-inspect.txt"

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

assert_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -F "$needle" "$file" >/dev/null; then
    printf 'unexpected credential-boundary leak: %s appeared in %s\n' "$needle" "$file" >&2
    return 1
  fi
}

cleanup() {
  .build/debug/sand delete "$NAME" --force >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

printf 'name=%s\nlog=%s\n' "$NAME" "$LOG"
run swift build || exit 1
run ./scripts/build-developer-ready-image.sh || exit 1
cleanup
TMP_DIR="$(mktemp -d)"
INSPECT_OUT="$TMP_DIR/container-inspect.txt"
trap cleanup EXIT

run .build/debug/sand create "$NAME" --cpus 2 --memory 1GB || exit 1
run .build/debug/sand "$NAME" spec || exit 1

run .build/debug/sand "$NAME" run pi --version || exit 1
printf 'UNAUTHENTICATED_PI_SMOKE=pi --version only; no human-authenticated Pi login or provider credential setup was attempted.\n'

run .build/debug/sand "$NAME" run bash -lc '
  set -euo pipefail
  test "$(readlink "$HOME/.pi")" = /state/sandbox/.pi
  test "$(readlink "$HOME/.sand-secrets")" = /state/sandbox/secrets
  printf PI_IDENTITY_MARKER > "$HOME/.pi/identity-marker"
  test "$(cat /state/sandbox/.pi/identity-marker)" = PI_IDENTITY_MARKER
  test ! -e /Users
  test ! -e /host
  test ! -e "$HOME/.aws"
  test ! -e "$HOME/.config/gcloud"
  test ! -e "$HOME/.ssh"
  test ! -S /run/host-services/ssh-auth.sock
  test -z "${SSH_AUTH_SOCK:-}"
' || exit 1

printf '\n$ container inspect "$NAME"\n'
container inspect "$NAME" > "$INSPECT_OUT"
status=$?
printf '[exit %s]\n' "$status"
if [ "$status" -ne 0 ]; then exit 1; fi
assert_not_contains "$INSPECT_OUT" "/Users/"
assert_not_contains "$INSPECT_OUT" ".aws"
assert_not_contains "$INSPECT_OUT" ".config/gcloud"
assert_not_contains "$INSPECT_OUT" "SSH_AUTH_SOCK"
assert_not_contains "$INSPECT_OUT" "/run/host-services"

run .build/debug/sand "$NAME" stop || exit 1
run .build/debug/sand apply "$NAME" || exit 1
run .build/debug/sand "$NAME" run bash -lc 'test "$(cat "$HOME/.pi/identity-marker")" = PI_IDENTITY_MARKER' || exit 1

printf '\n$ .build/debug/sand "$NAME" pi\n'
set +e
.build/debug/sand "$NAME" pi
status=$?
set -e
printf '[exit %s]\n' "$status"
if [ "$status" -eq 0 ]; then
  printf 'unexpected Pi shortcut command succeeded\n' >&2
  exit 1
fi

run .build/debug/sand delete "$NAME" --force || exit 1
trap - EXIT
rm -rf "$TMP_DIR"
printf '\nVALIDATION_PASS name=%s log=%s\n' "$NAME" "$LOG"
