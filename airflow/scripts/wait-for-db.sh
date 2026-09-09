#!/usr/bin/env bash

set -euo pipefail


log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}


DB_HOST="${DB_HOST:?DB_HOST is required}"
DB_PORT="${DB_PORT:-5432}"

MAX_RETRIES="${MAX_RETRIES:-30}"
SLEEP_SECONDS="${SLEEP_SECONDS:-5}"


log "Waiting for PostgreSQL..."

for ((i=1; i<=MAX_RETRIES; i++)); do

    if timeout 3 bash -c \
        "</dev/tcp/${DB_HOST}/${DB_PORT}" \
        2>/dev/null
    then
        log "PostgreSQL is reachable"
        exit 0
    fi

    log "PostgreSQL is not ready. Retry ${i}/${MAX_RETRIES}"

    sleep "${SLEEP_SECONDS}"
done


log "PostgreSQL did not become ready"
exit 1