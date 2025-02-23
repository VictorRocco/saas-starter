#!/bin/bash

# Source common variables and functions
source "$(dirname "$0")/make_common.sh" || {
    printf "${RED}❌ Failed to source make_common.sh${RESET}\n"
    exit 1
}

echo "Checking system dependencies..."

# Check Python3
if check_command "python3"; then
    PYTHON_PATH=$(which python3)
    CURRENT_PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info[0]}.{sys.version_info[1]}')")
    printf "${GREEN}✅ python3 is installed at %s (version: %s)${RESET}\n" "$PYTHON_PATH" "$CURRENT_PYTHON_VERSION"

    if [[ $(version_compare "$CURRENT_PYTHON_VERSION") -lt $(version_compare "$MIN_PYTHON_VERSION") ]]; then
        printf "${RED}❌ Python version %s is not sufficient (required >= %s)${RESET}\n" "$CURRENT_PYTHON_VERSION" "$MIN_PYTHON_VERSION"
        exit 1
    fi
else
    exit 1
fi

# Check pip3
if check_command "pip3"; then
    PIP_PATH=$(which pip3)
    CURRENT_PIP_VERSION=$(pip3 --version | awk '{print $2}' | cut -d'.' -f1-2)
    printf "${GREEN}✅ pip3 is installed at %s (version: %s)${RESET}\n" "$PIP_PATH" "$CURRENT_PIP_VERSION"

    if [[ $(version_compare "$CURRENT_PIP_VERSION") -lt $(version_compare "$MIN_PIP_VERSION") ]]; then
        printf "${RED}❌ pip version %s is not sufficient (required >= %s)${RESET}\n" "$CURRENT_PIP_VERSION" "$MIN_PIP_VERSION"
        exit 1
    fi
else
    exit 1
fi

# Check Docker
if check_command "docker"; then
    DOCKER_PATH=$(which docker)
    CURRENT_DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    printf "${GREEN}✅ docker is installed at %s (version: %s)${RESET}\n" "$DOCKER_PATH" "$CURRENT_DOCKER_VERSION"

    if [[ $(version_compare "$CURRENT_DOCKER_VERSION") -lt $(version_compare "$MIN_DOCKER_VERSION") ]]; then
        printf "${RED}❌ Docker version %s is not sufficient (required >= %s)${RESET}\n" "$CURRENT_DOCKER_VERSION" "$MIN_DOCKER_VERSION"
        exit 1
    fi
else
    exit 1
fi

# Check Docker Compose v2
if ! docker compose version > /dev/null 2>&1; then
    printf "${RED}❌ docker compose (v2) is not installed${RESET}\n"
    exit 1
else
    # Try different methods to get version
    DOCKER_COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || \
                           docker compose version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    
    if [ -z "$DOCKER_COMPOSE_VERSION" ]; then
        printf "${RED}❌ Could not determine Docker Compose version${RESET}\n"
        exit 1
    fi
    
    printf "${GREEN}✅ docker compose (v2) is installed (version: %s)${RESET}\n" "$DOCKER_COMPOSE_VERSION"

    if [[ $(version_compare "$DOCKER_COMPOSE_VERSION") -lt $(version_compare "$MIN_DOCKER_COMPOSE_VERSION") ]]; then
        printf "${RED}❌ Docker Compose version %s is not sufficient (required >= %s)${RESET}\n" "$DOCKER_COMPOSE_VERSION" "$MIN_DOCKER_COMPOSE_VERSION"
        exit 1
    fi
fi

printf "${GREEN}✅ All system dependencies are satisfied${RESET}\n"
exit 0