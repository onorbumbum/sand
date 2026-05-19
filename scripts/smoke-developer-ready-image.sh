#!/usr/bin/env bash
set -euo pipefail

IMAGE="${SAND_DEVELOPER_READY_IMAGE:-sand/developer-ready:ubuntu-lts}"
CONTAINER="${SAND_DEVELOPER_READY_SMOKE_CONTAINER:-sand-developer-ready-smoke}"

cleanup() {
  container delete --force "${CONTAINER}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup

container run \
  --name "${CONTAINER}" \
  --detach \
  --cpus 4 \
  --memory 8G \
  "${IMAGE}" \
  sleep 10000 >/dev/null

container exec --user sandbox --workdir /workspace "${CONTAINER}" bash -lc '
  set -euo pipefail

  printf "whoami -> %s\n" "$(whoami)"
  test "$(whoami)" = sandbox
  printf "pwd -> %s\n" "$(pwd)"
  test "$(pwd)" = /workspace
  printf "sudo -n whoami -> %s\n" "$(sudo -n whoami)"
  test "$(sudo -n whoami)" = root
  test -w /workspace
  test -w /state/sandbox
  test -d /state/sandbox/.pi
  test -d /state/sandbox/secrets
  printf "HOME/.pi -> %s\n" "$(readlink "$HOME/.pi")"
  test "$(readlink "$HOME/.pi")" = /state/sandbox/.pi
  printf "HOME/.sand-secrets -> %s\n" "$(readlink "$HOME/.sand-secrets")"
  test "$(readlink "$HOME/.sand-secrets")" = /state/sandbox/secrets
  test ! -e /Users
  test ! -e /host
  test ! -S /run/host-services/ssh-auth.sock
  test -z "${SSH_AUTH_SOCK:-}"

  command -v git
  git --version

  command -v curl
  curl --version | head -1

  command -v sudo
  sudo -V | head -1

  command -v ssh
  ssh -V

  command -v python3
  python3 --version
  python3 -m venv /tmp/sand-venv
  /tmp/sand-venv/bin/python -m pip --version

  command -v pip3
  pip3 --version

  command -v node
  node --version

  command -v npm
  npm --version

  command -v tmux
  tmux -V

  command -v rg
  rg --version | head -1

  command -v gcc
  gcc --version | head -1

  command -v make
  make --version | head -1

  command -v pi
  pi --version
'
