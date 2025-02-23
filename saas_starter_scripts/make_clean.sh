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

# Check if tracking file exists
TRACKING_FILE="../saas_starter_tracking.json"
if [ ! -f "$TRACKING_FILE" ]; then
    printf "${RED}❌ No tracked active project found. Exiting.${RESET}\n"
    exit 0
fi

# Stop containers and remove volumes if project directory exists
if [ -d "${PROJECT}" ]; then
    cd "${PROJECT}" && ${DOCKER_COMPOSE_COMMAND} down --volumes --remove-orphans -t 1
else
    printf "${YELLOW}⚠️ Project directory \"${PROJECT}\" not found, continuing with cleanup.${RESET}\n"
fi

# Cleanup Docker resources
docker network prune -f 2>/dev/null || true
docker volume prune -f 2>/dev/null || true

printf "${GREEN}✅ Project \"${PROJECT}\" containers and volumes have been removed.${RESET}\n"