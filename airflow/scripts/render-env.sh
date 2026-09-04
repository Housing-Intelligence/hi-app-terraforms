#!/usr/bin/env bash

set -euo pipefail

AIRFLOW_HOME="${AIRFLOW_HOME:?AIRFLOW_HOME is required}"
ENV_FILE="${AIRFLOW_HOME}/.env"

AIRFLOW_SECRET_ID="${AIRFLOW_SECRET_ID:?AIRFLOW_SECRET_ID is required}"
AIRFLOW_IMAGE="${AIRFLOW_IMAGE:?AIRFLOW_IMAGE is required}"
AWS_REGION="${AWS_REGION:?AWS_REGION is required}"

# Logging

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}


# Get Secret

get_secret() {

    log "Reading Airflow secret from Secrets Manager..."

    SECRET_JSON=$(aws secretsmanager get-secret-value \
        --region "${AWS_REGION}" \
        --secret-id "${AIRFLOW_SECRET_ID}" \
        --query 'SecretString' \
        --output text)

    if [[ -z "${SECRET_JSON}" || "${SECRET_JSON}" == "None" ]]; then
        log "SecretString is empty"
        exit 1
    fi

    log "Airflow secret loaded successfully"
}

# Extract Secrets

extract_secrets() {

    AIRFLOW_DB_CONNECTION=$(echo "${SECRET_JSON}" | jq -r '.db_connection')
    AIRFLOW_FERNET_KEY=$(echo "${SECRET_JSON}" | jq -r '.fernet_key')
    AIRFLOW_SECRET_KEY=$(echo "${SECRET_JSON}" | jq -r '.secret_key')

    if [[ -z "${AIRFLOW_DB_CONNECTION}" || "${AIRFLOW_DB_CONNECTION}" == "null" ]]; then
        log "db_connection is missing"
        exit 1
    fi

    if [[ -z "${AIRFLOW_FERNET_KEY}" || "${AIRFLOW_FERNET_KEY}" == "null" ]]; then
        log "fernet_key is missing"
        exit 1
    fi

    if [[ -z "${AIRFLOW_SECRET_KEY}" || "${AIRFLOW_SECRET_KEY}" == "null" ]]; then
        log "secret_key is missing"
        exit 1
    fi

    log "Required secrets validated"
}

# Render .env

render_env() {

    log "Rendering Airflow environment file..."

    mkdir -p "${AIRFLOW_HOME}"

    cat > "${ENV_FILE}" <<EOF
AIRFLOW_IMAGE=${AIRFLOW_IMAGE}

AIRFLOW_UID=50000

AIRFLOW__CORE__EXECUTOR=LocalExecutor

AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=${AIRFLOW_DB_CONNECTION}

AIRFLOW__CORE__FERNET_KEY=${AIRFLOW_FERNET_KEY}

AIRFLOW__API_AUTH__JWT_SECRET=${AIRFLOW_SECRET_KEY}

AIRFLOW__CORE__LOAD_EXAMPLES=false

AIRFLOW__WEBSERVER__EXPOSE_CONFIG=false

AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=true
EOF

    chmod 600 "${ENV_FILE}"

    log "Environment file created: ${ENV_FILE}"
}

# Main

main() {

    log "Starting Airflow environment rendering..."

    get_secret

    extract_secrets

    render_env

    log "Airflow environment rendering completed successfully."
}

main "$@"