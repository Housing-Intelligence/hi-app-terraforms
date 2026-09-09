#!/usr/bin/env bash

set -euo pipefail

# Logging

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Validate Environment

validate_environment() {

    log "Validating Airflow initialization environment..."

    : "${AIRFLOW_ADMIN_USERNAME:?AIRFLOW_ADMIN_USERNAME is required}"
    : "${AIRFLOW_ADMIN_FIRSTNAME:?AIRFLOW_ADMIN_FIRSTNAME is required}"
    : "${AIRFLOW_ADMIN_LASTNAME:?AIRFLOW_ADMIN_LASTNAME is required}"
    : "${AIRFLOW_ADMIN_EMAIL:?AIRFLOW_ADMIN_EMAIL is required}"
    : "${AIRFLOW_ADMIN_PASSWORD:?AIRFLOW_ADMIN_PASSWORD is required}"

    : "${AIRFLOW_POOL_NAME:?AIRFLOW_POOL_NAME is required}"
    : "${AIRFLOW_POOL_SLOTS:?AIRFLOW_POOL_SLOTS is required}"
    : "${AIRFLOW_POOL_DESCRIPTION:?AIRFLOW_POOL_DESCRIPTION is required}"

    : "${AIRFLOW_VARIABLES_FILE:?AIRFLOW_VARIABLES_FILE is required}"

    log "Environment validation completed."
}

# Database Migration

migrate_database() {

    log "Running Airflow database migration..."

    airflow db migrate

    log "Airflow database migration completed."
}

# Create Admin User

create_admin_user() {

    log "Checking Airflow admin user..."

    if airflow users list \
        --output plain |
        grep -Fxq "${AIRFLOW_ADMIN_USERNAME}"
    then
        log "Admin user already exists."

        return 0
    fi


    log "Creating Airflow admin user..."

    airflow users create \
        --username "${AIRFLOW_ADMIN_USERNAME}" \
        --firstname "${AIRFLOW_ADMIN_FIRSTNAME}" \
        --lastname "${AIRFLOW_ADMIN_LASTNAME}" \
        --role Admin \
        --email "${AIRFLOW_ADMIN_EMAIL}" \
        --password "${AIRFLOW_ADMIN_PASSWORD}"

    log "Airflow admin user created."
}

# Create Airflow Pool

create_pool() {

    log "Checking Airflow pool..."

    if airflow pools get "${AIRFLOW_POOL_NAME}" \
        >/dev/null 2>&1
    then

        log "Airflow pool already exists."

        return 0
    fi


    log "Creating Airflow pool..."

    airflow pools set \
        "${AIRFLOW_POOL_NAME}" \
        "${AIRFLOW_POOL_SLOTS}" \
        "${AIRFLOW_POOL_DESCRIPTION}"

    log "Airflow pool created."
}

# Create Airflow Connections

create_connections() {

    log "Configuring Airflow connections..."

    # AWS connection

    if airflow connections get aws_default \
        >/dev/null 2>&1
    then

        log "Connection already exists: aws_default"

    else

        airflow connections add \
            aws_default \
            --conn-type aws

        log "Created connection: aws_default"

    fi
    log "Airflow connections configured."
}

# Import Airflow Variables

import_variables() {

    log "Importing Airflow variables..."


    if [[ ! -f "${AIRFLOW_VARIABLES_FILE}" ]]; then

        log "Variables file does not exist:"
        log "${AIRFLOW_VARIABLES_FILE}"

        return 0
    fi


    airflow variables import \
        "${AIRFLOW_VARIABLES_FILE}"


    log "Airflow variables imported."
}

# Sync DAGs

# sync_dags() {

#     log "Synchronizing DAGs..."

#     /opt/airflow/scripts/sync-dags.sh

#     log "DAG synchronization completed."
# }


# Sync FAB Permissions

sync_fab_permissions() {

    log "Synchronizing FAB permissions..."

    airflow sync-perm \
        --include-dags

    log "FAB permissions synchronized."
}


# Main

main() {

    log "=========================================="
    log "Starting Airflow initialization"
    log "=========================================="
    validate_environment

    # 1. Wait for RDS

    log "Step 1/9: Waiting for database..."

    /opt/airflow/scripts/wait-for-db.sh

    # 2. Database migration

    log "Step 2/9: Running database migration..."

    migrate_database

    # 3. Create admin user

    log "Step 3/9: Creating admin user..."

    create_admin_user

    # 4. Create pools

    log "Step 4/9: Creating Airflow pool..."

    create_pool

    # 5. Create connections

    log "Step 5/9: Creating Airflow connections..."

    create_connections

    # 6. Import variables

    log "Step 6/9: Importing Airflow variables..."

    import_variables

    # 7. Sync DAGs

    # log "Step 7/9: Synchronizing DAGs..."

    # sync_dags

    # 8. Sync FAB permissions

    log "Step 8/9: Synchronizing FAB permissions..."

    sync_fab_permissions

    log "=========================================="
    log "Airflow initialization completed"
    log "=========================================="
}


main "$@"