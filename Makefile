# Makefile for SaaS Starter

# --- Variables ---

# Use docker compose (v2)
DOCKER_COMPOSE_COMMAND := docker compose

# Add minimum version requirements
MIN_PYTHON_VERSION := 3.8
MIN_PIP_VERSION := 20.0
MIN_DOCKER_VERSION := 20.0
MIN_DOCKER_COMPOSE_VERSION := 2.0

# --- Colors ---
RED := "\033[0;31m"
GREEN := "\033[0;32m"
YELLOW := "\033[0;33m"
RESET := "\033[0m" # Reset to default color

# --- Load tracking information ---
load_tracking_info = $(if $(wildcard ../saas_starter_tracking.json), \
	$(eval PROJECT := $(shell jq -r .project_name ../saas_starter_tracking.json)), \
	$(eval PROJECT := test))
$(call load_tracking_info)

# --- Helper functions ---
define check_version
	@if ! which $(1) > /dev/null 2>&1; then \
		echo "$(RED)❌ $(1) is not installed$(RESET)"; \
		exit 1; \
	else \
		echo "$(GREEN)✅ $(1) is installed at $$(which $(1))$(RESET)"; \
	fi
endef

define check_python_version
	@python3 -c "import sys; \
	current=tuple(map(int, '$(shell python3 --version | cut -d' ' -f2)'.split('.'))); \
	minimum=tuple(map(int, '$(MIN_PYTHON_VERSION)'.split('.'))); \
	exit(0 if current >= minimum else 1)" 2>/dev/null || \
	(echo "$(RED)❌ Python version must be >= $(MIN_PYTHON_VERSION)$(RESET)"; exit 1) && \
	echo "$(GREEN)✅ Python version is $(shell python3 --version | cut -d' ' -f2)$(RESET)"
endef

define check_docker_compose_file
	@if [ ! -f "$(PROJECT)/docker-compose.yml" ]; then \
		echo "❌ docker-compose.yml not found in $(PROJECT)/. Run 'make build' first."; \
		exit 1; \
	fi
endef

# --- Targets ---

.PHONY: help build up down logs weblogs dblogs clean migrate makemigrations shell superuser collectstatic test check check_docker_compose_file ps destroy

help:
	@echo "Available commands:"
	@echo "  make up             - Start the application"
	@echo "  make down           - Stop the application"
	@echo "  make build          - Build the application"
	@echo "  make logs           - View combined logs from all services"
	@echo "  make weblogs        - View logs from the 'web' service (your Django app)"
	@echo "  make dblogs         - View logs from the 'db' service (your database)"
	@echo "  make clean          - Remove the project"
	@echo "  make migrate        - Run database migrations."
	@echo "  make makemigrations - Create database migrations."
	@echo "  make shell          - Open a Django shell inside the web container."
	@echo "  make createsuperuser- Create a superuser."
	@echo "  make collectstatic  - Collect static files."
	@echo "  make test           - Run tests."
	@echo "  make check          - Check system dependencies."
	@echo "  make ps             - Show the status of running services."
	@echo "  make destroy        - Permanently destroy the project (cannot be undone!)"

check:
	@echo "Checking system dependencies..."
	$(call check_version,python3)
	$(call check_python_version)
	$(call check_version,pip3)
	$(call check_version,docker)
	@if ! docker compose version > /dev/null 2>&1; then \
		echo "$(RED)❌ docker compose (v2) is not installed$(RESET)"; \
		exit 1; \
	else \
		echo "$(GREEN)✅ docker compose (v2) is installed$(RESET)"; \
	fi
	@echo "$(GREEN)✅ All system dependencies are satisfied$(RESET)"

build: check
	./saas_starter_builder.sh

check_docker_compose_file:
	$(call check_docker_compose_file)

up: check_docker_compose_file
	cd $(PROJECT) && $(DOCKER_COMPOSE_COMMAND) up -d

down:
	cd $(PROJECT) && $(DOCKER_COMPOSE_COMMAND) down

logs: check_docker_compose_file
	cd $(PROJECT) && $(DOCKER_COMPOSE_COMMAND) logs -f

weblogs: check_docker_compose_file
	cd $(PROJECT) && $(DOCKER_COMPOSE_COMMAND) logs -f web

dblogs: check_docker_compose_file
	cd $(PROJECT) && $(DOCKER_COMPOSE_COMMAND) logs -f db

clean: ## Stop and remove containers, networks, and volumes
	@bash -c '\
		TRACKING_FILE="saas_starter_tracking.json"; \
		if [ ! -f "$$TRACKING_FILE" ]; then \
			echo '\''$(RED)❌ No tracked active project found. Exiting.$(RESET)'\''; \
			exit 0; \
		fi; \
		if [ -d "$(PROJECT)" ]; then \
			cd "$(PROJECT)" && $(DOCKER_COMPOSE_COMMAND) down --volumes --remove-orphans -t 1; \
		else \
			echo "Project directory \"$(PROJECT)\" not found, continuing with cleanup."; \
		fi; \
		docker network prune -f 2>/dev/null || true; \
		docker volume prune -f 2>/dev/null || true; \
		echo "Project \"$(PROJECT)\" containers and volumes have been removed.";'

migrate: check_docker_compose_file
	cd $(PROJECT) && $(DOCKER_COMPOSE_COMMAND) exec web python manage.py migrate

makemigrations: check_docker_compose_file
	cd $(PROJECT) && $(DOCKER_COMPOSE_COMMAND) exec web python manage.py makemigrations

shell: check_docker_compose_file
	@cd $(PROJECT) && $(DOCKER_COMPOSE_COMMAND) exec web python manage.py shell_plus 2>&1 | grep -q "is not running" && echo "The 'web' service is not running.  Run 'make up' to start the application." || $(DOCKER_COMPOSE_COMMAND) exec web python manage.py shell_plus

createsuperuser: check_docker_compose_file
	cd $(PROJECT) && $(DOCKER_COMPOSE_COMMAND) exec web python manage.py createsuperuser

collectstatic: check_docker_compose_file
	cd $(PROJECT) && $(DOCKER_COMPOSE_COMMAND) exec web python manage.py collectstatic --noinput

test: check_docker_compose_file
	cd $(PROJECT) && $(DOCKER_COMPOSE_COMMAND) exec web python manage.py test

ps: check_docker_compose_file
	cd $(PROJECT) && $(DOCKER_COMPOSE_COMMAND) ps

destroy: clean ## Remove project directory and tracking file
	@bash -c '\
		TRACKING_FILE="saas_starter_tracking.json"; \
		if [ ! -f "$$TRACKING_FILE" ]; then \
			echo '\''$(RED)❌ No tracked active project found. Exiting.$(RESET)'\''; \
			exit 0; \
		fi; \
		echo ""; \
		echo -e '\''$(RED)WARNING: This will permanently remove the project directory "$(PROJECT)" and tracking file.$(RESET)'\''; \
		echo -e '\''$(RED)This action CANNOT be undone.$(RESET)'\''; \
		echo ""; \
		read -r -p "Type '\''destroy'\'' to confirm: " confirmation; \
		if [ "$$confirmation" != "destroy" ]; then \
			echo "Destroy operation cancelled."; \
			exit 0; \
		fi; \
		if [ -d "$(PROJECT)" ]; then \
			rm -rf "$(PROJECT)"; \
			echo "Project directory \"$(PROJECT)\" has been removed."; \
		else \
			echo "Project directory \"$(PROJECT)\" not found."; \
		fi; \
		rm -f "$$TRACKING_FILE"; \
		echo "Tracking file has been removed.";'
