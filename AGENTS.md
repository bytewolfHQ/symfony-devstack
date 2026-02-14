# Repository Guidelines

## Project Structure & Module Organization
This is an infrastructure-only repo. Application code lives outside the repo and is mounted via `APP_DIR`. Key paths:
- `docker/php/` PHP-FPM image and entrypoint logic
- `docker/nginx/` Nginx config template
- `docker/certs/` local CA certs (ignored by Git; `.gitkeep` keeps the folder)

## Build, Test, and Development Commands
Use the Makefile-driven workflow:
- `make build` — build the php image
- `make up` / `make down` — start/stop the stack
- `make trust-certs` — refresh CA trust store in the running php container (runs as root in-container)
- `make logs SERVICE=nginx` — tail service logs
- `make shell SERVICE=php` or `make php` — open a shell in the php container
- `make composer CMD="install"` — run composer in the mounted app
- `make init-app SYMFONY_VERSION=6.4 APP_DIR=../new-app` — scaffold a new Symfony app into an empty directory (fails if non-empty)

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
- Never commit local IPs or certs. Use `.env` for local values and keep only placeholders in `.env.example`.
- Local CA certs go in `docker/certs/*.crt` (ignored by Git). Run `make trust-certs` (or `make up`) to trust new CAs.
- If you change `SHOPWARE_HOSTNAME` or `SHOPWARE_IP`, recreate containers so `/etc/hosts` updates.
- Containers run as your host user (via `UID`/`GID`) so files created in `APP_DIR` are not owned by root.
- The php entrypoint writes runtime INI files to `/tmp/php-conf` and uses `PHP_INI_SCAN_DIR` to include them.
- The php container runs unprivileged, so CA bundle updates must be executed as root (handled by `make trust-certs`).
- `make` loads `.env`, so `APP_DIR` and other defaults match docker compose unless you override on the command line.
