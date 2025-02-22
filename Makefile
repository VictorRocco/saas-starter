# Makefile for SaaS Starter

# --- Variables ---

# Use the project name from the environment variable if set, otherwise default to 'test'
PROJECT ?= $(shell basename $$(pwd))

# Use docker compose (v2)
DOCKER_COMPOSE_COMMAND := docker compose

# Add minimum version requirements
MIN_PYTHON_VERSION := 3.8
MIN_PIP_VERSION := 20.0
MIN_DOCKER_VERSION := 20.0
MIN_DOCKER_COMPOSE_VERSION := 2.0

# --- Helper functions ---
define check_version
	@if ! which $(1) > /dev/null 2>&1; then \
		echo "❌ $(1) is not installed"; \
		exit 1; \
	else \
		echo "✅ $(1) is installed at $$(which $(1))"; \
	fi
endef

define check_python_version
	@python3 -c "import sys; \
	current=tuple(map(int, '$(shell python3 --version | cut -d' ' -f2)'.split('.'))); \
	minimum=tuple(map(int, '$(MIN_PYTHON_VERSION)'.split('.'))); \
	exit(0 if current >= minimum else 1)" 2>/dev/null || \
	(echo "❌ Python version must be >= $(MIN_PYTHON_VERSION)"; exit 1) && \
	echo "✅ Python version is $(shell python3 --version | cut -d' ' -f2)"
endef

define check_docker_compose_file
	@if [ ! -f "docker-compose.yml" ]; then \
		echo "❌ docker-compose.yml not found. Run 'make build' first."; \
		exit 1; \
	fi
endef

# --- Targets ---

.PHONY: help build up down logs weblogs dblogs clean migrate makemigrations shell superuser collectstatic test check check_docker_compose_file ps

help:
	@echo "Available commands:"
	@echo "  make up           - Start the application"
	@echo "  make down         - Stop the application"
	@echo "  make build        - Build the application"
	@echo "  make logs         - View application logs"
	@echo "  make clean        - Remove the project"
	@echo "  migrate          - Run database migrations."
	@echo "  makemigrations   - Create database migrations."
	@echo "  shell            - Open a Django shell inside the web container."
	@echo "  createsuperuser  - Create a superuser."
	@echo "  collectstatic    - Collect static files."
	@echo "  test             - Run tests."
	@echo "  check            - Check system dependencies."
	@echo "  ps               - Show the status of running services."

check:
	@echo "Checking system dependencies..."
	$(call check_version,python3)
	$(call check_python_version)
	$(call check_version,pip3)
	$(call check_version,docker)
	@if ! docker compose version > /dev/null 2>&1; then \
		echo "❌ docker compose (v2) is not installed"; \
		exit 1; \
	else \
		echo "✅ docker compose (v2) is installed"; \
	fi
	@echo "✅ All system dependencies are satisfied"

build: check
	cd $(PROJECT) && docker compose build

check_docker_compose_file:
	$(call check_docker_compose_file)

up: check_docker_compose_file
	cd $(PROJECT) && docker compose up -d

down:
	cd $(PROJECT) && docker compose down

logs: check_docker_compose_file
	cd $(PROJECT) && docker compose logs -f

weblogs: check_docker_compose_file
	$(DOCKER_COMPOSE_COMMAND) logs -f web

dblogs: check_docker_compose_file
	$(DOCKER_COMPOSE_COMMAND) logs -f db

clean: down
	cd $(PROJECT) && docker compose down --volumes --remove-orphans
	rm -rf $(PROJECT)
	docker network prune -f 2>/dev/null || true
	docker volume prune -f 2>/dev/null || true

migrate: check_docker_compose_file
	$(DOCKER_COMPOSE_COMMAND) exec web python manage.py migrate

makemigrations: check_docker_compose_file
	$(DOCKER_COMPOSE_COMMAND) exec web python manage.py makemigrations

shell: check_docker_compose_file
	$(DOCKER_COMPOSE_COMMAND) exec web python manage.py shell_plus

createsuperuser: check_docker_compose_file
	$(DOCKER_COMPOSE_COMMAND) exec web python manage.py createsuperuser

collectstatic: check_docker_compose_file
	$(DOCKER_COMPOSE_COMMAND) exec web python manage.py collectstatic --noinput

test: check_docker_compose_file
	$(DOCKER_COMPOSE_COMMAND) exec web python manage.py test

ps: check_docker_compose_file
	$(DOCKER_COMPOSE_COMMAND) ps
