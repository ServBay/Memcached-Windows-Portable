#!/bin/sh
# Docker wrapper for memcached-mingw build and test.
# Usage: docker.sh {build|start|stop|restart|clean}

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE_NAME="memcached-mingw-builder"
CONTAINER_NAME="memcached-mingw-build"
PARALLEL="${PARALLEL:-5}"
CPU="${CPU:-64}"

# Use sudo if docker is not accessible directly
_docker() {
    if docker ps >/dev/null 2>&1; then
        docker "$@"
    else
        sudo docker "$@"
    fi
}

case "${1:-}" in
    build)
        _docker build -t "${IMAGE_NAME}" \
            -f "${REPO_ROOT}/mingw/Dockerfile" \
            "${REPO_ROOT}"
        ;;
    start)
        # Remove any leftover container from a previous run
        _docker rm "${CONTAINER_NAME}" 2>/dev/null || true
        _docker run --name "${CONTAINER_NAME}" \
            -v "${REPO_ROOT}:${REPO_ROOT}" -w "${REPO_ROOT}" \
            -e PARALLEL="${PARALLEL}" \
            -e CPU="${CPU}" \
            -e CODECOV_DISABLE=1 \
            "${IMAGE_NAME}" \
            sh -c "cd mingw/build && ./_build.sh"
        ;;
    stop)
        _docker stop "${CONTAINER_NAME}" 2>/dev/null || true
        ;;
    restart)
        "$0" stop
        "$0" start
        ;;
    clean)
        _docker stop "${CONTAINER_NAME}" 2>/dev/null || true
        _docker rm "${CONTAINER_NAME}" 2>/dev/null || true
        _docker rmi "${IMAGE_NAME}" 2>/dev/null || true
        ;;
    *)
        echo "Usage: $0 {build|start|stop|restart|clean}" >&2
        exit 1
        ;;
esac
