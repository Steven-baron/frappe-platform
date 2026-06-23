#!/usr/bin/env bash
# Build the frappe-platform images locally.
#
# Usage:
#   ./build-local.sh          # build base (~20 min) then apps layer (~2 min)
#   ./build-local.sh --fast   # skip base build, pull existing :base-16 from GHCR

set -euo pipefail
cd "$(dirname "$0")"

IMAGE="${IMAGE:-ghcr.io/steven-baron/erpnext-crm}"

# ── Base image ────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--fast" ]]; then
    echo "==> --fast: using existing base image"
    # Try local first, then pull from GHCR
    if docker image inspect "${IMAGE}:base-16" &>/dev/null; then
        echo "    ${IMAGE}:base-16 already present locally"
    else
        echo "    Pulling ${IMAGE}:base-16 from GHCR..."
        docker pull "${IMAGE}:base-16" || {
            echo ""
            echo "ERROR: ${IMAGE}:base-16 not found."
            echo "Options:"
            echo "  1. Run without --fast to build it from scratch (~20 min)"
            echo "  2. Simulate a base with the current production image:"
            echo "     docker pull ${IMAGE}:16"
            echo "     docker tag  ${IMAGE}:16 ${IMAGE}:base-16"
            exit 1
        }
    fi
else
    echo "==> Building base image (frappe + erpnext + CRM + Helpdesk) — ~20 min"
    [[ -d frappe_docker ]] || git clone --depth 1 https://github.com/frappe/frappe_docker.git

    DOCKER_BUILDKIT=1 docker build \
        --build-arg FRAPPE_PATH=https://github.com/frappe/frappe \
        --build-arg FRAPPE_BRANCH=version-16 \
        --build-arg "CACHE_BUST=$(md5sum apps-base.json | cut -c1-8)" \
        --secret id=apps_json,src="$(pwd)/apps-base.json" \
        --tag "${IMAGE}:base-16" \
        --file frappe_docker/images/layered/Containerfile \
        frappe_docker
    echo "==> Base built: ${IMAGE}:base-16"
fi

# ── Apps layer ────────────────────────────────────────────────────────────────
echo ""
echo "==> Building apps layer (+ custom apps) — ~1-2 min"

# Use current timestamp as APPS_SHA to always re-clone during local builds
docker build \
    --build-arg "APPS_SHA=$(date +%s)" \
    --tag "${IMAGE}:16" \
    --tag "${IMAGE}:latest" \
    .

echo ""
echo "==> Done."
echo "    ${IMAGE}:base-16  — base framework"
echo "    ${IMAGE}:16       — base + custom apps"
echo ""
echo "==> Run locally:"
echo "    docker compose -f docker-compose.yml -f docker-compose.local.yml --env-file .env.local up -d"
