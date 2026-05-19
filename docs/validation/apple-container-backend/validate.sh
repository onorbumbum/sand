#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
LOG="$ROOT/run-$(date +%Y%m%d-%H%M%S).log"
IMAGE="sand-validation-dev:latest"
CONTAINER="sand-validation-spike"
VOLUME="sand-validation-state"
HOST_ROOT="/tmp/sand-backend-validation"
RW_DIR="$HOST_ROOT/rw"
RO_DIR="$HOST_ROOT/ro"

exec > >(tee "$LOG") 2>&1

step() {
  printf '\n\n### %s\n' "$1"
}

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

cleanup_runtime() {
  container delete --force "$CONTAINER" >/dev/null 2>&1 || true
}

cleanup_all() {
  cleanup_runtime
  container volume delete "$VOLUME" >/dev/null 2>&1 || true
}

step "Versions and backend service"
run which container || exit 1
run container --version || exit 1
run container system status || exit 1
run container system start || exit 1
run container system status || exit 1
run container list --all || true

step "Prepare host folders and clean previous validation resources"
cleanup_all
run rm -rf "$HOST_ROOT"
run mkdir -p "$RW_DIR/subdir" "$RO_DIR"
run_sh "echo host-original > '$RW_DIR/host-owned.txt'"
run_sh "echo readonly-host > '$RO_DIR/read-only-host.txt'"
run ls -lna "$HOST_ROOT" "$RW_DIR" "$RO_DIR"

step "Build developer-ready validation image"
run container build --progress plain -t "$IMAGE" "$ROOT" || exit 1

step "Create Guest State volume and runtime with read-write/read-only Allowed Folders"
run container volume create "$VOLUME" || exit 1
run container run \
  --name "$CONTAINER" \
  --detach \
  --cpus 4 \
  --memory 8G \
  --volume "$VOLUME:/state" \
  --mount "type=bind,source=$RW_DIR,target=/workspace/rw" \
  --mount "type=bind,source=$RO_DIR,target=/workspace/ro,readonly" \
  "$IMAGE" \
  sleep 10000 || exit 1
run container inspect "$CONTAINER" || true

step "Non-root interactive Sandbox Session evidence"
run container exec --tty --user sandbox --workdir /workspace "$CONTAINER" bash -lc 'tty; whoami; pwd' || exit 1
run container exec --user sandbox "$CONTAINER" bash -lc 'id && test "$(whoami)" = sandbox' || exit 1

step "Passwordless sudo inside Sandbox Guest"
run container exec --user sandbox "$CONTAINER" bash -lc 'sudo -n whoami && test "$(sudo -n whoami)" = root' || exit 1
run container exec --user sandbox "$CONTAINER" bash -lc 'sudo -n install -d -o sandbox -g sandbox /state/sandbox && test -w /state/sandbox' || exit 1

step "Read-write Allowed Folder and Host-Safe File Ownership"
run container exec --user sandbox --workdir /workspace/rw "$CONTAINER" bash -lc 'echo guest-created > guest-created.txt && echo guest-modified >> host-owned.txt && pwd' || exit 1
run ls -lna "$RW_DIR"
run cat "$RW_DIR/guest-created.txt" "$RW_DIR/host-owned.txt"
HOST_UID="$(id -u)"
run_sh "test \"\$(stat -f '%u' '$RW_DIR/guest-created.txt')\" = '$HOST_UID'"
run_sh "test \"\$(stat -f '%u' '$RW_DIR/host-owned.txt')\" = '$HOST_UID'"

step "Read-only Allowed Folder blocks writes"
run_sh "container exec --user sandbox --workdir /workspace/ro '$CONTAINER' bash -lc 'echo should-fail > blocked.txt' && exit 1 || exit 0" || exit 1
run_sh "test ! -e '$RO_DIR/blocked.txt'" || exit 1

step "Working Directory Mapping can start inside mounted folder"
run container exec --user sandbox --workdir /workspace/rw/subdir "$CONTAINER" bash -lc 'pwd && echo mapped > mapped.txt' || exit 1
run cat "$RW_DIR/subdir/mapped.txt" || exit 1

step "Persistent Guest State survives stop/start"
run container exec --user sandbox "$CONTAINER" bash -lc 'echo before-stop > /state/sandbox/persistent.txt' || exit 1
run container stop "$CONTAINER" || exit 1
run container start "$CONTAINER" || exit 1
run container exec --user sandbox "$CONTAINER" bash -lc 'cat /state/sandbox/persistent.txt && test "$(cat /state/sandbox/persistent.txt)" = before-stop' || exit 1

step "Multiple Sandbox Sessions can run concurrently"
run container exec --detach --user sandbox "$CONTAINER" bash -lc 'sleep 3; echo session-one > /state/sandbox/session-one.txt' || exit 1
run container exec --detach --user sandbox "$CONTAINER" bash -lc 'sleep 3; echo session-two > /state/sandbox/session-two.txt' || exit 1
run container exec --user sandbox "$CONTAINER" bash -lc 'pgrep -a sleep || true' || true
run sleep 5
run container exec --user sandbox "$CONTAINER" bash -lc 'cat /state/sandbox/session-one.txt /state/sandbox/session-two.txt' || exit 1

step "Outbound-only networking without published ports"
run container exec --user sandbox "$CONTAINER" bash -lc 'curl -fsSL https://example.com >/tmp/example.html && test -s /tmp/example.html' || exit 1
run container inspect "$CONTAINER" || true

step "Default Toolset smoke test and Pi CLI installation path check"
run container exec --user sandbox "$CONTAINER" bash -lc 'for c in git curl sudo ssh python3 npm node tmux rg gcc make; do printf "%s -> " "$c"; command -v "$c"; done' || exit 1
run_sh "container exec --user sandbox '$CONTAINER' bash -lc 'npm view @mariozechner/pi-coding-agent version' || true"

step "Runtime recreation preserves Guest State and intended Allowed Folder behavior"
run container delete --force "$CONTAINER" || exit 1
run container run \
  --name "$CONTAINER" \
  --detach \
  --cpus 4 \
  --memory 8G \
  --volume "$VOLUME:/state" \
  --mount "type=bind,source=$RW_DIR,target=/workspace/rw" \
  --mount "type=bind,source=$RO_DIR,target=/workspace/ro,readonly" \
  "$IMAGE" \
  sleep 10000 || exit 1
run container exec --user sandbox "$CONTAINER" bash -lc 'cat /state/sandbox/persistent.txt /state/sandbox/session-one.txt /state/sandbox/session-two.txt' || exit 1
run container exec --user sandbox --workdir /workspace/rw "$CONTAINER" bash -lc 'echo recreated >> host-owned.txt && cat host-owned.txt' || exit 1
run_sh "container exec --user sandbox --workdir /workspace/ro '$CONTAINER' bash -lc 'echo should-fail-after-recreate > blocked-after-recreate.txt' && exit 1 || exit 0" || exit 1
run_sh "test ! -e '$RO_DIR/blocked-after-recreate.txt'" || exit 1

step "Cleanup validation runtime resources"
cleanup_all
run ls -lna "$RW_DIR" "$RO_DIR"

step "Conclusion"
echo "Validation script completed successfully. Log: $LOG"
