#!/bin/bash

# Get absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR" || exit 1

# Source common variables and functions
source "$SCRIPT_DIR/make_common.sh" || {
    printf "${RED}❌ Failed to source make_common.sh${RESET}\n"
    exit 1
}

# Check if docker-compose.yml exists
if [ ! -f "${PROJECT}/docker-compose.yml" ]; then
    printf "${RED}❌ docker-compose.yml not found in ${PROJECT}/. Run 'make build' first.${RESET}\n"
    exit 1
fi

# Get service name from arguments (optional)
SERVICE=$1

if [ -n "$SERVICE" ]; then
    cd "${PROJECT}" && ${DOCKER_COMPOSE_COMMAND} logs -f "$SERVICE"
else
    cd "${PROJECT}" && ${DOCKER_COMPOSE_COMMAND} logs -f
fi