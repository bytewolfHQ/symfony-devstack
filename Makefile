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
WEBAPP ?= 0

.PHONY: up down build restart logs shell php composer exec console init-app smoke trust-certs use

use:
	@test -n "$(ENV)" || { echo "Usage: make use ENV=<name>  (erwartet .env.<name>)"; exit 1; }
	@test -f .env.$(ENV) || { echo ".env.$(ENV) not found"; exit 1; }
	ln -sf .env.$(ENV) .env
	@echo "Aktiv: .env -> .env.$(ENV)"

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
	$(COMPOSE) run --rm php composer $(CMD)

# Beliebigen Befehl im laufenden Service ausfuehren, z.B.:
#   make exec CMD="bin/console cache:clear"
#   make exec SERVICE=db CMD="mysql -uapp -papp app"
exec:
	$(COMPOSE) exec $(SERVICE) $(CMD)

# Shortcut speziell fuer Symfonys bin/console, z.B.:
#   make console CMD="cache:clear"
#   make console CMD="make:entity"
console:
	$(COMPOSE) exec php bin/console $(CMD)

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
	$(COMPOSE) run --rm php composer create-project symfony/skeleton:"$(SYMFONY_VERSION).*" .
	@if [ "$(WEBAPP)" = "1" ]; then \
		echo "Installing webapp pack (Twig, Doctrine, Security, Forms, Stimulus, Turbo)..."; \
		$(COMPOSE) run --rm php composer require webapp; \
	fi

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
