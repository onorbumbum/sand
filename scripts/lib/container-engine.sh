# Picks the engine that builds and runs Linux sandbox images.
# Apple `container` where it exists (Apple silicon, macOS 26); Docker otherwise.
# Override with SAND_LINUX_BACKEND=apple-container|docker, matching the sand CLI.

case "${SAND_LINUX_BACKEND:-}" in
  apple-container) SAND_ENGINE=container ;;
  docker) SAND_ENGINE=docker ;;
  *)
    if command -v container >/dev/null 2>&1; then
      SAND_ENGINE=container
    else
      SAND_ENGINE=docker
    fi
    ;;
esac

# Removes a container by name on either engine, ignoring "not found".
sand_engine_remove() {
  if [ "${SAND_ENGINE}" = container ]; then
    container delete --force "$1" >/dev/null 2>&1 || true
  else
    docker rm --force "$1" >/dev/null 2>&1 || true
  fi
}
