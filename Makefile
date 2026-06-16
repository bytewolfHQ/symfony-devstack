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

.PHONY: help up down build restart logs shell php composer exec console init-app smoke trust-certs use

.DEFAULT_GOAL := help

help: ## Diese Liste anzeigen
	@grep -h -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*##"}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

use: ## .env auf .env.<name> umlinken, z.B. make use ENV=todo-app
	@test -n "$(ENV)" || { echo "Usage: make use ENV=<name>  (erwartet .env.<name>)"; exit 1; }
	@test -f .env.$(ENV) || { echo ".env.$(ENV) not found"; exit 1; }
	ln -sf .env.$(ENV) .env
	@echo "Aktiv: .env -> .env.$(ENV)"

up: ## Stack starten (im Hintergrund) und CA-Zertifikate auffrischen
	$(COMPOSE) up -d --remove-orphans
	@$(MAKE) trust-certs

down: ## Stack stoppen und Container entfernen
	$(COMPOSE) down

build: ## php-Image bauen (noetig nach Aenderung von PHP_VERSION/COMPOSER_VERSION)
	$(COMPOSE) build php

restart: ## Alle Container neu starten (ohne Neubau)
	$(COMPOSE) restart

logs: ## Logs eines Service folgen, z.B. make logs SERVICE=nginx
	$(COMPOSE) logs -f --tail=100 $(SERVICE)

shell: ## Shell in einem Service oeffnen, z.B. make shell SERVICE=db
	$(COMPOSE) exec $(SERVICE) sh

php: ## Shell im php-Container oeffnen
	$(COMPOSE) exec php sh

composer: ## Composer im php-Service ausfuehren, z.B. make composer CMD="install"
	$(COMPOSE) run --rm php composer $(CMD)

exec: ## Beliebigen Befehl in einem Service ausfuehren, z.B. make exec CMD="bin/console cache:clear"
	$(COMPOSE) exec $(SERVICE) $(CMD)

console: ## Shortcut fuer bin/console, z.B. make console CMD="cache:clear"
	$(COMPOSE) exec php bin/console $(CMD)

init-app: ## Symfony-Skeleton in APP_DIR anlegen, z.B. make init-app SYMFONY_VERSION=7.4 WEBAPP=1
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

smoke: ## Pruefen, ob die App unter APP_HOST/APP_PORT antwortet
	@curl -fsS http://$(APP_HOST):$(APP_PORT)/ > /dev/null
	@echo "OK"

trust-certs: ## CA-Zertifikate aus docker/certs/*.crt im php-Container vertrauen
	@if ls docker/certs/*.crt >/dev/null 2>&1; then \
		echo "Refreshing CA certificates inside php container..."; \
		$(COMPOSE) exec -T -u root php sh -lc 'update-ca-certificates >/dev/null && echo "CA certificates refreshed."'; \
	else \
		echo "No custom CA certificates found in docker/certs/*.crt; skipping."; \
	fi
