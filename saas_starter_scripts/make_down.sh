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

# Stop the application
cd "${PROJECT}" && ${DOCKER_COMPOSE_COMMAND} down

printf "${GREEN}✅ Application stopped successfully${RESET}\n"