# symfony-devstack

Infrastructure-only Docker development stack for Symfony (6.x/7.x) or any PHP app. This repo contains no application code. Your app lives outside this repo and is mounted into the containers via `APP_DIR`.

PHP version, database version/credentials, Composer version, and ports are all configurable per project via `.env` — nothing is hardcoded in the Dockerfile or compose file beyond sane defaults.

## Why this repo is infra-only
- Keeps your app repo clean and portable.
- Allows multiple projects to share the same dev stack.
- Lets you swap Symfony, PHP, and DB versions per project without touching this repo's code.

## Quick start
1) Clone this repo and create a local `.env`:
```sh
cp .env.example .env
```

2) Create an app directory outside this repo (default is `../app`):
```sh
mkdir -p ../app
```

3) (Optional) Add a local CA for HTTPS inside the php container:
- Drop any `.crt` files into `docker/certs/` (this folder is ignored by Git).
- Restart the stack to rebuild the CA bundle.

4) Optionally create a Symfony skeleton into `APP_DIR`:
```sh
make init-app SYMFONY_VERSION=7.4
```
Note: `make init-app` requires `APP_DIR` to be empty. To scaffold into a new directory:
```sh
make init-app SYMFONY_VERSION=7.4 APP_DIR=../new-app
```

5) Build and start the stack:
```sh
make build
make up
```
If `docker/certs/*.crt` contains custom CAs, `make up` also refreshes the php trust store.

Visit `http://localhost:8080` (or `APP_HOST`/`APP_PORT`).

## Running multiple projects with one devstack
Instead of a single shared `.env`, keep one file per project (`.env.<name>`) and switch between them:
```sh
cp .env.example .env.todo-app
# edit .env.todo-app: APP_DIR, APP_PORT, PHP_VERSION, DB_*, ADMINER_PORT, SYMFONY_VERSION, ...
make use ENV=todo-app   # symlinks .env -> .env.todo-app
make up
```
`.env` is a symlink managed by `make use`; only `.env.example` is tracked in Git, all `.env*` files are ignored (see `.gitignore`). Give each project its own `APP_PORT`/`ADMINER_PORT` if you plan to run more than one stack at the same time.

## Choosing Symfony version
`make init-app` accepts `SYMFONY_VERSION=6.x` or `7.x`:
```sh
make init-app SYMFONY_VERSION=7.4
```
This only runs `composer create-project symfony/skeleton`. To also pull in the full "webapp" pack (Twig, Doctrine, Security, Forms, Symfony UX/Stimulus/Turbo), add `WEBAPP=1`:
```sh
make init-app SYMFONY_VERSION=7.4 APP_DIR=../todo-app WEBAPP=1
```
(`webapp` is a Flex pack alias, not a real Composer package — it's installed via a follow-up `composer require webapp`, not `create-project`.)

This only runs once to scaffold a project. You can also use this stack for existing apps.

## Dynamic image versions
These are build args / env vars, not hardcoded — override them per project in `.env.<name>`:

| Variable | Default | Notes |
|---|---|---|
| `PHP_VERSION` | `8.3` | Build arg for the php image. Changing it requires `make build`. |
| `COMPOSER_VERSION` | `2` | Composer is copied into the php image from `composer:${COMPOSER_VERSION}` at build time (multi-stage build), so it always runs on the *same* PHP version as the app — no more platform mismatches between a separate Composer container and the runtime image. |
| `DB_VERSION` | `11` | MariaDB image tag. |
| `DB_NAME` / `DB_USER` / `DB_PASSWORD` / `DB_ROOT_PASSWORD` | `app` / `app` / `app` / `root` | Must stay in sync with `DATABASE_URL`. |
| `ADMINER_PORT` | `8081` | Change if running several projects in parallel. |

Watch your PHP version against current package requirements: some Symfony/Doctrine/PHPUnit releases bump their minimum PHP version (e.g. `doctrine/doctrine-bundle` 3.2.x and `phpunit` 13.2.x currently require PHP `8.4`). If `composer update` complains about your PHP version, bump `PHP_VERSION` in `.env.<name>` and `make build` again rather than fighting the lock file.

## Traefik (optional)
This stack is Traefik-compatible but does not run Traefik. To integrate, uncomment the labels in `docker-compose.yml` and attach the `traefik-proxy` network. Traefik should run externally.

## HTTPS vs HTTP
HTTP is enabled by default. For HTTPS, terminate TLS at Traefik or another reverse proxy. Local certs can be stored under `docker/certs/` if you add your own proxy.

## Reaching services on your LAN
If you need to call a local service from the php container (e.g., a Shopware server), map it via `extra_hosts` using environment variables:
- Set `SHOPWARE_HOSTNAME` and `SHOPWARE_IP` in `.env`.
- Restart containers (`make down && make up`) so `/etc/hosts` updates.
For HTTPS with a local CA, place the CA cert in `docker/certs/` as a `.crt` and restart so it is trusted.

## Common pitfalls
- BuildKit required: the php image build uses `# syntax=docker/dockerfile:1` and a named composer stage. This needs Docker BuildKit/`docker buildx` available (`docker buildx version`). If missing, install the `docker-buildx-plugin` for your distro.
- Permissions: ensure your host user can write to `APP_DIR`.
- Trusted proxies: Symfony may need trusted proxy configuration when behind Traefik.
- Stale upstream IPs: Nginx uses Docker DNS resolver with a variable upstream to avoid stale IP issues.
- Xdebug: enable with `ENABLE_XDEBUG=1` in `.env` before starting containers.
- PhpStorm CLI debug mapping: set `PHP_IDE_CONFIG=serverName=symfony-devstack` and configure a PhpStorm server with that exact name and path mapping `/var/www/html` -> your local `APP_DIR`.
- If breakpoints are not hit in CLI commands, run once with explicit env overrides: `docker compose exec -e PHP_IDE_CONFIG="serverName=symfony-devstack" -e XDEBUG_CONFIG="idekey=PHPSTORM client_host=host.docker.internal client_port=9003" php sh -lc 'php bin/console ...'`.
- Recreating a bind-mounted `APP_DIR` (e.g. `rm -rf ../app && mkdir ../app`) while containers are running breaks the mount and causes `docker exec` to fail with "possible container breakout detected". Fix with a full `make down && make up`, not just `make restart`.

## Troubleshooting TLS to LAN services
If `curl` fails with `unable to get local issuer certificate` inside the php container:
1) Ensure your local CA is in `docker/certs/` with a `.crt` extension.
2) Restart the stack so the CA bundle is rebuilt:
```sh
make down
make up
```
Or refresh CAs in a running stack:
```sh
make trust-certs
```
3) Validate inside the php container:
```sh
make php
curl -v https://your-hostname 2>&1 | grep -E "SSL|issuer|subject"
```

## Shopware OAuth token endpoint
`/api/oauth/token` expects `POST` (not `GET`). A `405` response with valid TLS usually means the method is wrong.

## Useful commands
```sh
make use ENV=todo-app
make build
make up
make down
make logs SERVICE=nginx
make shell SERVICE=php
make php
make composer CMD="install"
make console CMD="cache:clear"
make exec CMD="bin/console make:entity"
make exec SERVICE=db CMD="mysql -uapp -papp app"
make init-app SYMFONY_VERSION=7.4 APP_DIR=../todo-app WEBAPP=1
make smoke
make trust-certs
```

## Running console/arbitrary commands
For Symfony's `bin/console`, use the shortcut:
```sh
make console CMD="cache:clear"
make console CMD="make:entity"
```
For anything else (any service, any command), use the generic `exec` target instead of typing out `docker compose exec ...`:
```sh
make exec CMD="bin/console doctrine:migrations:status"
make exec SERVICE=db CMD="mysql -uapp -papp app"
```

## Composer usage
Composer is baked into the `php` image (`COPY --from=composer:${COMPOSER_VERSION}` via a named build stage), so it always runs on the exact same PHP version/extensions that execute the app. Run it through the `php` service, not a separate container:
```sh
docker compose run --rm php composer require --dev symfony/maker-bundle
# or via Makefile:
make composer CMD="require --dev symfony/maker-bundle"
```

## File ownership
Containers run as your host user (via `UID`/`GID`), so files created under `APP_DIR` are owned by you, not root.
