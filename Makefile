SHELL := /bin/sh
COMPOSE := docker compose

# Load .env so docker compose sees the same defaults as make.
# Command-line overrides still win (e.g., make up APP_DIR=../newapp).
-include .env

APP_DIR ?= ../app
APP_HOST ?= localhost
APP_PORT ?= 8080
SYMFONY_VERSION ?= 6.4
UID ?= $(shell id -u)
GID ?= $(shell id -g)

# Export so docker compose sees Make overrides (e.g. make init-app APP_DIR=../newapp)
export APP_DIR
export APP_HOST
export APP_PORT
export SYMFONY_VERSION
export UID
export GID
SERVICE ?= php
CMD ?=

.PHONY: up down build restart logs shell php composer init-app smoke trust-certs

up:
	$(COMPOSE) up -d --remove-orphans
	@$(MAKE) trust-certs

down:
	$(COMPOSE) down

build:
	$(COMPOSE) build php

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f --tail=100 $(SERVICE)

shell:
	$(COMPOSE) exec $(SERVICE) sh

php:
	$(COMPOSE) exec php sh

composer:
	$(COMPOSE) run --rm composer $(CMD)

init-app:
	@case "$(SYMFONY_VERSION)" in \
		6.*|7.*) ;; \
		*) echo "SYMFONY_VERSION must be 6.x or 7.x"; exit 1 ;; \
	esac
	@mkdir -p $(APP_DIR)
	@if [ -n "$$(ls -A $(APP_DIR) 2>/dev/null)" ]; then \
		echo "APP_DIR '$(APP_DIR)' is not empty. Choose an empty directory or override APP_DIR for init-app."; \
		echo "Example: make init-app SYMFONY_VERSION=$(SYMFONY_VERSION) APP_DIR=../new-app"; \
		exit 1; \
	fi
	$(COMPOSE) run --rm composer create-project symfony/skeleton:"$(SYMFONY_VERSION).*" /app

smoke:
	@curl -fsS http://$(APP_HOST):$(APP_PORT)/ > /dev/null
	@echo "OK"

trust-certs:
	@if ls docker/certs/*.crt >/dev/null 2>&1; then \
		echo "Refreshing CA certificates inside php container..."; \
		$(COMPOSE) exec -T -u root php sh -lc 'update-ca-certificates >/dev/null && echo "CA certificates refreshed."'; \
	else \
		echo "No custom CA certificates found in docker/certs/*.crt; skipping."; \
	fi
