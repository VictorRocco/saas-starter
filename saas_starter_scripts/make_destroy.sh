#!/bin/bash

# Get absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR" || exit 1

# Skip tracking check from common.sh since we'll handle it ourselves
export SKIP_TRACKING=1

# Source common variables and functions
source "$SCRIPT_DIR/make_common.sh" || {
    printf "${RED}❌ Failed to source make_common.sh${RESET}\n"
    exit 1
}

# Get project name from tracking file
PROJECT_NAME=$(python3 "$SCRIPT_DIR/utils.py" read "$TRACKING_FILE" "project_name")
if [ $? -ne 0 ]; then
    printf "${RED}❌ No tracked active project found. Exiting.${RESET}\n"
    exit 1
fi

# Clean up containers and volumes if they exist
if [ -f "${PROJECT_NAME}/docker-compose.yml" ]; then
    cd "${PROJECT_NAME}" && $DOCKER_COMPOSE_COMMAND down -v --remove-orphans &> /dev/null
fi

echo ""
printf "${RED}WARNING: This will permanently remove the project directory \"${PROJECT_NAME}\" and tracking file.${RESET}\n"
printf "${RED}This action CANNOT be undone.${RESET}\n"
echo ""
read -r -p "Type 'destroy' to confirm: " confirmation

if [ "$confirmation" != "destroy" ]; then
    echo "Destroy operation cancelled."
    exit 0
fi

# Remove project directory if it exists
if [ -d "${PROJECT_NAME}" ]; then
    rm -rf "${PROJECT_NAME}" || {
        printf "${RED}❌ Failed to remove project directory${RESET}\n"
        exit 1
    }
    printf "${GREEN}✅ Project directory \"${PROJECT_NAME}\" has been removed.${RESET}\n"
else
    printf "${YELLOW}⚠️ Project directory \"${PROJECT_NAME}\" not found.${RESET}\n"
fi

# Remove tracking file if it exists
if [ -f "$TRACKING_FILE" ]; then
    rm -f "$TRACKING_FILE" || {
        printf "${RED}❌ Failed to remove tracking file${RESET}\n"
        exit 1
    }
    printf "${GREEN}✅ Tracking file has been removed.${RESET}\n"
else
    printf "${YELLOW}⚠️ Tracking file not found.${RESET}\n"
fi

# Remove log file if it exists
LOG_FILE="$ROOT_DIR/saas_starter_log.txt"
if [ -f "$LOG_FILE" ]; then
    rm -f "$LOG_FILE" || {
        printf "${RED}❌ Failed to remove log file${RESET}\n"
        exit 1
    }
    printf "${GREEN}✅ Log file has been removed.${RESET}\n"
fi