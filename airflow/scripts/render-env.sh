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

    RDS_HOST=$(echo "${SECRET_JSON}" | jq -r '.rds.host')
    RDS_PORT=$(echo "${SECRET_JSON}" | jq -r '.rds.port')
    RDS_DATABASE=$(echo "${SECRET_JSON}" | jq -r '.rds.database')
    RDS_USERNAME=$(echo "${SECRET_JSON}" | jq -r '.rds.username')
    RDS_PASSWORD=$(echo "${SECRET_JSON}" | jq -r '.rds.password')

    # REDIS_HOST=$(echo "${SECRET_JSON}" | jq -r '.redis.host')
    # REDIS_PORT=$(echo "${SECRET_JSON}" | jq -r '.redis.port')
    # REDIS_PASSWORD=$(echo "${SECRET_JSON}" | jq -r '.redis.password')

    AIRFLOW_ADMIN_USERNAME=$(echo "${SECRET_JSON}" | jq -r '.airflow.admin_username')
    AIRFLOW_ADMIN_FIRSTNAME=$(echo "${SECRET_JSON}" | jq -r '.airflow.admin_firstname')
    AIRFLOW_ADMIN_LASTNAME=$(echo "${SECRET_JSON}" | jq -r '.airflow.admin_lastname')
    AIRFLOW_ADMIN_EMAIL=$(echo "${SECRET_JSON}" | jq -r '.airflow.admin_email')
    AIRFLOW_ADMIN_PASSWORD=$(echo "${SECRET_JSON}" | jq -r '.airflow.admin_password')
    AIRFLOW_API_SECRET_KEY=$(echo "${SECRET_JSON}" | jq -r '.airflow.api_secret_key')

    AIRFLOW_FERNET_KEY=$(echo "${SECRET_JSON}" | jq -r '.airflow.fernet_key')
    AIRFLOW_JWT_SECRET=$(echo "${SECRET_JSON}" | jq -r '.airflow.jwt_secret')


    if [[ -z "${RDS_HOST}" || "${RDS_HOST}" == "null" ]]; then
        log "RDS host is missing"
        exit 1
    fi

    if [[ -z "${RDS_PORT}" || "${RDS_PORT}" == "null" ]]; then
        log "RDS port is missing"
        exit 1
    fi

    if [[ -z "${RDS_DATABASE}" || "${RDS_DATABASE}" == "null" ]]; then
        log "RDS database is missing"
        exit 1
    fi

    if [[ -z "${RDS_USERNAME}" || "${RDS_USERNAME}" == "null" ]]; then
        log "RDS username is missing"
        exit 1
    fi

    if [[ -z "${RDS_PASSWORD}" || "${RDS_PASSWORD}" == "null" ]]; then
        log "RDS password is missing"
        exit 1
    fi

    if [[ -z "${AIRFLOW_API_SECRET_KEY}" ||
      "${AIRFLOW_API_SECRET_KEY}" == "null" ]]; then
    log "API secret key is missing"
    exit 1
    fi

    # if [[ -z "${REDIS_HOST}" || "${REDIS_HOST}" == "null" ]]; then
    #     log "Redis host is missing"
    #     exit 1
    # fi

    # if [[ -z "${REDIS_PASSWORD}" || "${REDIS_PASSWORD}" == "null" ]]; then
    #     log "Redis password is missing"
    #     exit 1
    # fi

    if [[ -z "${AIRFLOW_FERNET_KEY}" || "${AIRFLOW_FERNET_KEY}" == "null" ]]; then
        log "Fernet key is missing"
        exit 1
    fi

    if [[ -z "${AIRFLOW_JWT_SECRET}" || "${AIRFLOW_JWT_SECRET}" == "null" ]]; then
        log "JWT secret is missing"
        exit 1
    fi


    AIRFLOW_DB_CONNECTION="postgresql+psycopg2://${RDS_USERNAME}:${RDS_PASSWORD}@${RDS_HOST}:${RDS_PORT}/${RDS_DATABASE}"

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

AIRFLOW__CORE__AUTH_MANAGER=airflow.providers.fab.auth_manager.FabAuthManager

AIRFLOW__API_AUTH__JWT_SECRET=${AIRFLOW_JWT_SECRET}

AIRFLOW__CORE__LOAD_EXAMPLES=false

AIRFLOW__API__EXPOSE_CONFIG=false

AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=true

AIRFLOW_VARIABLES_FILE=/opt/airflow/config/variables.json

AIRFLOW_ADMIN_USERNAME=${AIRFLOW_ADMIN_USERNAME}

AIRFLOW_ADMIN_FIRSTNAME=${AIRFLOW_ADMIN_FIRSTNAME}

AIRFLOW_ADMIN_LASTNAME=${AIRFLOW_ADMIN_LASTNAME}

AIRFLOW_ADMIN_EMAIL=${AIRFLOW_ADMIN_EMAIL}

AIRFLOW_ADMIN_PASSWORD=${AIRFLOW_ADMIN_PASSWORD}

AIRFLOW__API__SECRET_KEY=${AIRFLOW_API_SECRET_KEY}

AIRFLOW_POOL_NAME=default_pool

AIRFLOW_POOL_SLOTS=10

AIRFLOW_POOL_DESCRIPTION=Default Airflow pool

DB_HOST=${RDS_HOST}

DB_PORT=${RDS_PORT}

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