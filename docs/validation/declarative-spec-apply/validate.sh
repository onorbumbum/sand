#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LOG="$ROOT/docs/validation/declarative-spec-apply/run-$(date +%Y%m%d-%H%M%S).log"
NAME="sand-apply-$(date +%H%M%S)"
HOST_ROOT="/tmp/sand-declarative-apply-$NAME"
CODE_DIR="$HOST_ROOT/code"
EXTRA_DIR="$HOST_ROOT/extra"
RUNNING_DIR="$HOST_ROOT/running"
SPEC_FILE="$HOST_ROOT/spec.yaml"
SAND="$ROOT/.build/debug/sand"

mkdir -p "$(dirname "$LOG")"
exec > >(tee "$LOG") 2>&1

step() { printf '\n\n### %s\n' "$1"; }
run() { printf '\n$ %s\n' "$*"; "$@"; local status=$?; printf '[exit %s]\n' "$status"; return "$status"; }
run_sh() { printf '\n$ %s\n' "$*"; bash -lc "$*"; local status=$?; printf '[exit %s]\n' "$status"; return "$status"; }

write_spec() {
  local include_extra="$1"
  local include_running="$2"
  local cpus="$3"
  cat > "$SPEC_FILE" <<YAML
schemaVersion: 1
name: $NAME
image: sand/developer-ready:ubuntu-lts
resources:
  cpus: $cpus
  memory: 1GB
allowedFolders:
  - hostPath: $CODE_DIR
    resolvedHostPath: $CODE_DIR
    guestPath: /code
    accessMode: read-write
YAML
  if [ "$include_extra" = "yes" ]; then
    cat >> "$SPEC_FILE" <<YAML
  - hostPath: $EXTRA_DIR
    resolvedHostPath: $EXTRA_DIR
    guestPath: /extra
    accessMode: read-only
YAML
  fi
  if [ "$include_running" = "yes" ]; then
    cat >> "$SPEC_FILE" <<YAML
  - hostPath: $RUNNING_DIR
    resolvedHostPath: $RUNNING_DIR
    guestPath: /running
    accessMode: read-only
YAML
  fi
}

install_active_spec() {
  cp "$SPEC_FILE" "$HOME/.sand/specs/$NAME.yaml"
}

cleanup() {
  "$SAND" delete "$NAME" --force >/dev/null 2>&1 || true
  container delete --force "$NAME" >/dev/null 2>&1 || true
  container volume delete "sand-state-$NAME" >/dev/null 2>&1 || true
  rm -rf "$HOST_ROOT"
  rm -f "$HOME/.sand/specs/$NAME.yaml" "$HOME/.sand/created-specs/$NAME.yaml"
}
trap cleanup EXIT

step "Build sand and prepare declarative spec inputs"
run swift build --package-path "$ROOT"
cleanup
run mkdir -p "$CODE_DIR" "$EXTRA_DIR" "$RUNNING_DIR"
run_sh "echo code-host > '$CODE_DIR/code.txt'"
run_sh "echo extra-host > '$EXTRA_DIR/extra.txt'"
run_sh "echo running-host > '$RUNNING_DIR/running.txt'"
write_spec no no 2
run cat "$SPEC_FILE"

step "Create real Sandbox VM from user-authored spec without a CLI name"
run "$SAND" create --from "$SPEC_FILE"
run_sh "test -f '$HOME/.sand/specs/$NAME.yaml'"
run_sh "test -f '$HOME/.sand/created-specs/$NAME.yaml'"
run "$SAND" "$NAME" start
run "$SAND" "$NAME" run bash -lc 'cat /code/code.txt && sudo sh -c "echo guest-state-marker > /state/apply-marker"'
run "$SAND" "$NAME" stop

step "Manual spec edit applies real backend configuration while preserving Guest State"
write_spec yes no 2
install_active_spec
run "$SAND" apply "$NAME"
run "$SAND" "$NAME" run bash -lc 'cat /extra/extra.txt && sudo cat /state/apply-marker'

step "Running apply asks before interrupting and cancellation leaves backend unchanged"
write_spec yes yes 2
install_active_spec
if printf 'n\n' | "$SAND" apply "$NAME"; then
  echo "cancelled running apply unexpectedly succeeded" >&2
  exit 1
else
  echo "running apply prompted and cancelled"
fi
if "$SAND" "$NAME" run bash -lc 'test -f /running/running.txt'; then
  echo "cancelled running apply still changed backend configuration" >&2
  exit 1
else
  echo "cancelled running apply did not expose /running"
fi

step "Approved running apply reconciles backend and preserves Guest State"
printf 'y\n' | "$SAND" apply "$NAME"
run "$SAND" "$NAME" run bash -lc 'cat /running/running.txt && sudo cat /state/apply-marker'

step "Unsupported resource edits after creation are rejected before backend mutation"
write_spec yes yes 4
install_active_spec
if "$SAND" apply "$NAME"; then
  echo "CPU edit after creation was accepted" >&2
  exit 1
else
  echo "CPU edit after creation rejected"
fi

step "Cleanup through sand delete removes runtime and metadata"
run "$SAND" delete "$NAME" --force
run_sh "test ! -f '$HOME/.sand/specs/$NAME.yaml'"
run_sh "test ! -f '$HOME/.sand/created-specs/$NAME.yaml'"
run_sh "test \"\$(container inspect '$NAME' 2>/dev/null || true)\" = '[]'"
trap - EXIT
rm -rf "$HOST_ROOT"

echo "Validation completed successfully. Log: $LOG"
