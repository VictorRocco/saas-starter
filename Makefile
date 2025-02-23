# Makefile for SaaS Starter

# --- Variables ---

# Use docker compose (v2)
DOCKER_COMPOSE_COMMAND := docker compose

# Add minimum version requirements
MIN_PYTHON_VERSION := 3.8
MIN_PIP_VERSION := 22.0
MIN_DOCKER_VERSION := 24.0
MIN_DOCKER_COMPOSE_VERSION := 2.30

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RESET := \033[0m

# Scripts directory
SCRIPTS_DIR := saas_starter_scripts

# --- Load tracking information ---
load_tracking_info = $(if $(wildcard ../saas_starter_tracking.json), \
	$(eval PROJECT := $(shell jq -r .project_name ../saas_starter_tracking.json)), \
	$(eval PROJECT := test))
$(call load_tracking_info)

# --- Helper functions ---
define check_docker_compose_file
	@if [ ! -f "$(PROJECT)/docker-compose.yml" ]; then \
		echo "❌ docker-compose.yml not found in $(PROJECT)/. Run 'make build' first."; \
		exit 1; \
	fi
endef

# --- Targets ---

.PHONY: help build up down logs weblogs dblogs clean migrate makemigrations shell createsuperuser collectstatic test check ps destroy

help:
	@echo "Available commands:"
	@echo "  make up             - Start the application"
	@echo "  make down           - Stop the application"
	@echo "  make build          - Build the application"
	@echo "  make logs           - View combined logs from all services"
	@echo "  make weblogs        - View logs from the 'web' service (your Django app)"
	@echo "  make dblogs         - View logs from the 'db' service (your database)"
	@echo "  make clean          - Remove the project"
	@echo "  make migrate        - Run database migrations"
	@echo "  make makemigrations - Create database migrations"
	@echo "  make shell          - Open a Django shell inside the web container"
	@echo "  make createsuperuser- Create a superuser"
	@echo "  make collectstatic  - Collect static files"
	@echo "  make test           - Run tests"
	@echo "  make check          - Check system dependencies"
	@echo "  make ps             - Show the status of running services"
	@echo "  make destroy        - Permanently destroy the project (cannot be undone!)"

check:
	@$(SCRIPTS_DIR)/make_check.sh

build: check
	@$(SCRIPTS_DIR)/make_build.sh

check_docker_compose_file:
	$(call check_docker_compose_file)

up: check
	@$(SCRIPTS_DIR)/make_up.sh

down:
	@$(SCRIPTS_DIR)/make_down.sh

logs:
	@$(SCRIPTS_DIR)/make_logs.sh

weblogs:
	@$(SCRIPTS_DIR)/make_logs.sh web

dblogs:
	@$(SCRIPTS_DIR)/make_logs.sh db

clean:
	@$(SCRIPTS_DIR)/make_clean.sh

migrate:
	@$(SCRIPTS_DIR)/make_django.sh migrate

makemigrations:
	@$(SCRIPTS_DIR)/make_django.sh makemigrations

shell:
	@$(SCRIPTS_DIR)/make_django.sh shell

createsuperuser:
	@$(SCRIPTS_DIR)/make_django.sh createsuperuser

collectstatic:
	@$(SCRIPTS_DIR)/make_django.sh collectstatic

test:
	@$(SCRIPTS_DIR)/make_django.sh test

ps: check
	@$(SCRIPTS_DIR)/make_logs.sh ps

destroy: clean
	@$(SCRIPTS_DIR)/make_destroy.sh
