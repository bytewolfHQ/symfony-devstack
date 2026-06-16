# Repository Guidelines

## Project Structure & Module Organization
This is an infrastructure-only repo. Application code lives outside the repo and is mounted via `APP_DIR`. Key paths:
- `docker/php/` PHP-FPM image and entrypoint logic
- `docker/nginx/` Nginx config template
- `docker/certs/` local CA certs (ignored by Git; `.gitkeep` keeps the folder)

## Build, Test, and Development Commands
Use the Makefile-driven workflow:
- `make use ENV=<name>` — symlink `.env` to `.env.<name>` (switch between projects sharing this devstack)
- `make build` — build the php image (rerun after changing `PHP_VERSION`/`COMPOSER_VERSION`)
- `make up` / `make down` — start/stop the stack
- `make trust-certs` — refresh CA trust store in the running php container (runs as root in-container)
- `make logs SERVICE=nginx` — tail service logs
- `make shell SERVICE=php` or `make php` — open a shell in the php container
- `make composer CMD="install"` — run composer via the `php` service (Composer is built into the php image, not a separate container; see below)
- `make init-app SYMFONY_VERSION=7.4 APP_DIR=../new-app` — scaffold a new Symfony app into an empty directory (fails if non-empty); add `WEBAPP=1` to also run `composer require webapp` (Twig, Doctrine, Security, Forms, Stimulus, Turbo)

## Coding Style & Naming Conventions
This repo contains no application code. Infrastructure files should use simple, readable defaults and keep values configurable via `.env`.

## Testing Guidelines
No tests are defined in this repo. If you add CI or linting for the stack files, document commands here.

## Commit & Pull Request Guidelines
The Git history currently contains a single “Initial commit,” so no conventions are established. When contributing:
- Use clear, scoped messages (e.g., `feat: add Docker compose file`).
- Keep commits focused on one change.
- PRs should include a short summary, rationale, and any setup/verification steps.
If screenshots or logs are relevant, attach them to the PR description.

## Configuration & Security Tips
- Never commit local IPs or certs. Use `.env.<project>` for local values and keep only placeholders in `.env.example`. All `.env*` files are gitignored except `.env.example`.
- Local CA certs go in `docker/certs/*.crt` (ignored by Git). Run `make trust-certs` (or `make up`) to trust new CAs.
- If you change `SHOPWARE_HOSTNAME` or `SHOPWARE_IP`, recreate containers so `/etc/hosts` updates.
- Containers run as your host user (via `UID`/`GID`) so files created in `APP_DIR` are not owned by root.
- The php entrypoint writes runtime INI files to `/tmp/php-conf` and uses `PHP_INI_SCAN_DIR` to include them.
- The php container runs unprivileged, so CA bundle updates must be executed as root (handled by `make trust-certs`).
- `make` loads `.env`, so `APP_DIR` and other defaults match docker compose unless you override on the command line.
- `PHP_VERSION` and `COMPOSER_VERSION` are Docker build args (`docker/php/Dockerfile`). Composer is copied from `composer:${COMPOSER_VERSION}` into the php image via a named build stage at build time, guaranteeing it resolves dependencies against the exact PHP version that runs them — there is no longer a standalone `composer` service. Changing either var requires `make build`.
- Building the php image requires BuildKit (`# syntax=docker/dockerfile:1` + named stages for ARG-driven `COPY --from`). If `make build` fails with "variable expansion is not supported for --from" or similar, ensure `docker buildx` is installed.
- Don't pin a project's `PHP_VERSION` below what its current dependencies require — Symfony/Doctrine/PHPUnit minor releases regularly bump their minimum PHP version. `composer update` failures citing your PHP version are a signal to bump `PHP_VERSION`, not to fight the lock file.
