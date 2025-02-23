#!/bin/bash

# Source common variables and functions
source "$(dirname "$0")/make_common.sh" || {
    printf "${RED}❌ Failed to source make_common.sh${RESET}\n"
    exit 1
}

# Stop the application
cd "${PROJECT}" && ${DOCKER_COMPOSE_COMMAND} down

printf "${GREEN}✅ Application stopped successfully${RESET}\n" 