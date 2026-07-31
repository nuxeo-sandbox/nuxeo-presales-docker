#!/usr/bin/env bash
# =============================================================================
# build-nuxeo-mcp.sh - build & (re)start the Nuxeo MCP server (profile "mcp").
#
# The mcp image is built from a LOCAL clone (NUXEO_MCP_SRC), so the image
# reflects whatever branch is checked out there. Docker cannot check out a
# branch from a local-directory build context, so this script does it for you
# before building.
#
# Reads from ./.env:
#   NUXEO_MCP_SRC     absolute path to your nuxeo-mcp-server clone (required)
#   NUXEO_MCP_BRANCH  branch to build; EMPTY = build whatever is checked out
#
# Usage:  ./scripts/build-nuxeo-mcp.sh
# Health: curl http://127.0.0.1:8181/health
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_DIR}/.env"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "ERROR: ${ENV_FILE} not found. Run bootstrap.sh (with MCP enabled) first." >&2
    exit 1
fi

# Read only the keys we need from .env (do NOT source it: values may have spaces).
get_env() {
  { grep -E "^${1}=" "${ENV_FILE}" || true; } | tail -n1 | cut -d= -f2-
}
NUXEO_MCP_SRC="${NUXEO_MCP_SRC:-$(get_env NUXEO_MCP_SRC)}"
NUXEO_MCP_BRANCH="${NUXEO_MCP_BRANCH:-$(get_env NUXEO_MCP_BRANCH)}"

: "${NUXEO_MCP_SRC:?NUXEO_MCP_SRC is not set in .env}"

if [[ ! -d "${NUXEO_MCP_SRC}/.git" ]]; then
    echo "ERROR: NUXEO_MCP_SRC (${NUXEO_MCP_SRC}) is not a git clone." >&2
    exit 1
fi

if [[ -n "${NUXEO_MCP_BRANCH}" ]]; then
    echo "==> Target branch: ${NUXEO_MCP_BRANCH}"
    current_branch="$(git -C "${NUXEO_MCP_SRC}" rev-parse --abbrev-ref HEAD)"

    echo "==> Fetching origin..."
    git -C "${NUXEO_MCP_SRC}" fetch origin

    # Protect work-in-progress: refuse to switch AWAY from a dirty branch.
    if [[ "${current_branch}" != "${NUXEO_MCP_BRANCH}" ]]; then
        if [[ -n "$(git -C "${NUXEO_MCP_SRC}" status --porcelain)" ]]; then
            echo "ERROR: clone is on '${current_branch}' with uncommitted changes." >&2
            echo "       Commit/stash them before switching to '${NUXEO_MCP_BRANCH}'." >&2
            exit 1
        fi
        echo "==> Checking out ${NUXEO_MCP_BRANCH}..."
        git -C "${NUXEO_MCP_SRC}" checkout "${NUXEO_MCP_BRANCH}"
    else
        echo "==> Already on ${NUXEO_MCP_BRANCH} (local changes, if any, built as-is)."
    fi

    # Fast-forward only: never clobber local commits/WIP.
    if git -C "${NUXEO_MCP_SRC}" pull --ff-only; then
        :
    else
        echo "WARNING: could not fast-forward '${NUXEO_MCP_BRANCH}' (diverged or local commits)." >&2
        echo "         Building the current local state instead." >&2
    fi
else
    echo "==> NUXEO_MCP_BRANCH empty: building currently checked-out branch."
fi

echo "==> Building from: $(git -C "${NUXEO_MCP_SRC}" rev-parse --abbrev-ref HEAD) @ $(git -C "${NUXEO_MCP_SRC}" rev-parse --short HEAD)"
echo "==> docker compose --profile mcp up -d --build mcp ..."
docker compose --project-directory "${PROJECT_DIR}" --file "${COMPOSE_FILE}" --profile mcp up -d --build mcp

echo
echo "Done. Check health:  curl http://127.0.0.1:8181/health"
