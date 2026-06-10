#!/bin/sh
set -eu

if [ "$#" -eq 0 ]; then
  set -- notion-manager
fi

if [ "${1#-}" != "$1" ]; then
  set -- notion-manager "$@"
fi

if [ "$(id -u)" = "0" ]; then
  mkdir -p /app/accounts

  if ! su-exec app:app sh -c 'test -w /app && test -w /app/accounts'; then
    chown -R app:app /app
  fi

  exec su-exec app:app "$@"
fi

exec "$@"
