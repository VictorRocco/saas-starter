#!/bin/bash

# Source common variables and functions
source "$(dirname "$0")/make_common.sh" || {
    printf "${RED}❌ Failed to source make_common.sh${RESET}\n"
    exit 1
}

# Check if docker-compose.yml exists
if [ ! -f "${PROJECT}/docker-compose.yml" ]; then
    printf "${RED}❌ docker-compose.yml not found in ${PROJECT}/. Run 'make build' first.${RESET}\n"
    exit 1
fi

# Start the application
cd "${PROJECT}" && ${DOCKER_COMPOSE_COMMAND} up -d

printf "${GREEN}✅ Application started successfully${RESET}\n" 