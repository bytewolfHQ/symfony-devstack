#!/usr/bin/env sh
set -eu

CONF_DIR="/tmp/php-conf"
XDEBUG_DISABLED="/usr/local/etc/php/conf.d/xdebug.ini.disabled"
XDEBUG_ENABLED="${CONF_DIR}/xdebug.ini"
MEMORY_LIMIT_INI="${CONF_DIR}/memory-limit.ini"

mkdir -p "${CONF_DIR}"

if [ "${ENABLE_XDEBUG:-0}" = "1" ]; then
  if [ -f "${XDEBUG_DISABLED}" ]; then
    cp "${XDEBUG_DISABLED}" "${XDEBUG_ENABLED}"
  fi
else
  rm -f "${XDEBUG_ENABLED}"
fi

if ls /usr/local/share/ca-certificates/*.crt >/dev/null 2>&1; then
  if [ "$(id -u)" = "0" ]; then
    update-ca-certificates >/dev/null
  else
    echo "Custom CAs found, but running unprivileged; skipping update-ca-certificates." >&2
  fi
fi

echo "memory_limit=${PHP_MEMORY_LIMIT:-512M}" > "${MEMORY_LIMIT_INI}"

exec docker-php-entrypoint "$@"
