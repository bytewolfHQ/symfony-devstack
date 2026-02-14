# symfony-devstack

Infrastructure-only Docker development stack for Symfony (6.x/7.x) or any PHP app. This repo contains no application code. Your app lives outside this repo and is mounted into the containers via `APP_DIR`.

## Why this repo is infra-only
- Keeps your app repo clean and portable.
- Allows multiple projects to share the same dev stack.
- Lets you swap Symfony versions at creation time.

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

3) Optionally create a Symfony skeleton into `APP_DIR`:
```sh
make init-app SYMFONY_VERSION=6.4
```
Note: `make init-app` requires `APP_DIR` to be empty. To scaffold into a new directory:
```sh
make init-app SYMFONY_VERSION=6.4 APP_DIR=../new-app
```

4) Start the stack:
```sh
make up
```
If `docker/certs/*.crt` contains custom CAs, `make up` also refreshes the php trust store.

Visit `http://localhost:8080` (or `APP_HOST`/`APP_PORT`).

## Choosing Symfony version
`make init-app` accepts `SYMFONY_VERSION=6.x` or `7.x`:
```sh
make init-app SYMFONY_VERSION=7.0
```
This only runs once to scaffold a project. You can also use this stack for existing apps.

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
- Permissions: ensure your host user can write to `APP_DIR`.
- Trusted proxies: Symfony may need trusted proxy configuration when behind Traefik.
- Stale upstream IPs: Nginx uses Docker DNS resolver with a variable upstream to avoid stale IP issues.
- Xdebug: enable with `ENABLE_XDEBUG=1` in `.env` before starting containers.

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
make build
make up
make logs SERVICE=nginx
make shell SERVICE=php
make php
make composer CMD="install"
make smoke
make trust-certs
```

## Composer usage
Composer is provided via a dedicated container. For example:
```sh
docker compose run --rm composer require --dev symfony/maker-bundle
```

## File ownership
Containers run as your host user (via `UID`/`GID`), so files created under `APP_DIR` are owned by you, not root.
