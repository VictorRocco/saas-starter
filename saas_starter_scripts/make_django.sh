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

# Get command from first argument
COMMAND=$1

if [ -z "$COMMAND" ]; then
    printf "${RED}❌ No command specified. Available commands: migrate, makemigrations, shell, createsuperuser, collectstatic, test${RESET}\n"
    exit 1
fi

case $COMMAND in
    "migrate")
        cd "${PROJECT}" && ${DOCKER_COMPOSE_COMMAND} exec web python manage.py migrate
        ;;
    "makemigrations")
        cd "${PROJECT}" && ${DOCKER_COMPOSE_COMMAND} exec web python manage.py makemigrations
        ;;
    "shell")
        cd "${PROJECT}" && ${DOCKER_COMPOSE_COMMAND} exec web python manage.py shell_plus
        ;;
    "createsuperuser")
        cd "${PROJECT}" && ${DOCKER_COMPOSE_COMMAND} exec web python manage.py createsuperuser
        ;;
    "collectstatic")
        cd "${PROJECT}" && ${DOCKER_COMPOSE_COMMAND} exec web python manage.py collectstatic --noinput
        ;;
    "test")
        cd "${PROJECT}" && ${DOCKER_COMPOSE_COMMAND} exec web python manage.py test
        ;;
    *)
        printf "${RED}❌ Unknown command: %s${RESET}\n" "$COMMAND"
        printf "Available commands: migrate, makemigrations, shell, createsuperuser, collectstatic, test\n"
        exit 1
        ;;
esac

printf "${GREEN}✅ Command '%s' completed successfully${RESET}\n" "$COMMAND"