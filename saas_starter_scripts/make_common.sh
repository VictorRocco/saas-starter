#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Docker compose command
DOCKER_COMPOSE_COMMAND="docker compose"

# Minimum version requirements
MIN_PYTHON_VERSION="3.8"
MIN_PIP_VERSION="22.0"
MIN_DOCKER_VERSION="24.0"
MIN_DOCKER_COMPOSE_VERSION="2.30"

# Get project name from tracking file
TRACKING_FILE="../saas_starter_tracking.json"

# Common functions
function check_command() {
    if ! command -v "$1" &> /dev/null; then
        printf "${RED}❌ %s is not installed${RESET}\n" "$1"
        return 1
    fi
    return 0
}

function version_compare() {
    echo "$1" | awk -F. '{ printf("%d%02d", $1, $2); }'
}

function check_docker_compose() {
    if [ ! -f "${PROJECT}/docker-compose.yml" ]; then
        printf "${RED}❌ docker-compose.yml not found in ${PROJECT}/. Run 'make build' first.${RESET}\n"
        return 1
    fi
    return 0
}

function get_tracking_param() {
    local param_name=$1
    if [ -f "$TRACKING_FILE" ]; then
        local param_value=$(jq -r ".$param_name" "$TRACKING_FILE")
        if [ "$param_value" != "null" ]; then
            echo "$param_value"
            return 0
        fi
    fi
    return 1
}

# Update the existing PROJECT assignment - store status in variable
PROJECT=$(get_tracking_param "project_name")
TRACKING_READ_STATUS=$?
