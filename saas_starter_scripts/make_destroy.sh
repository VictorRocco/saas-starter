#!/bin/bash

# Source common variables and functions
source "$(dirname "$0")/make_common.sh" || {
    printf "${RED}❌ Failed to source make_common.sh${RESET}\n"
    exit 1
}

# Clean up first
"$(dirname "$0")/make_clean.sh"

# Check if tracking file exists
TRACKING_FILE="../saas_starter_tracking.json"
if [ ! -f "$TRACKING_FILE" ]; then
    printf "${RED}❌ No tracked active project found. Exiting.${RESET}\n"
    exit 0
fi

echo ""
printf "${RED}WARNING: This will permanently remove the project directory \"${PROJECT}\" and tracking file.${RESET}\n"
printf "${RED}This action CANNOT be undone.${RESET}\n"
echo ""
read -r -p "Type 'destroy' to confirm: " confirmation

if [ "$confirmation" != "destroy" ]; then
    echo "Destroy operation cancelled."
    exit 0
fi

# Remove project directory if it exists
if [ -d "${PROJECT}" ]; then
    rm -rf "${PROJECT}"
    printf "${GREEN}✅ Project directory \"${PROJECT}\" has been removed.${RESET}\n"
else
    printf "${YELLOW}⚠️ Project directory \"${PROJECT}\" not found.${RESET}\n"
fi

# Remove tracking file
rm -f "$TRACKING_FILE"
printf "${GREEN}✅ Tracking file has been removed.${RESET}\n" 