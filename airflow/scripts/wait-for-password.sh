#!/usr/bin/env bash

set -euo pipefail

AIRFLOW_SECRET_ID="${AIRFLOW_SECRET_ID:?AIRFLOW_SECRET_ID is required}"
AWS_REGION="${AWS_REGION:?AWS_REGION is required}"

echo "Waiting for Airflow secret..."

until aws secretsmanager get-secret-value \
    --secret-id "${AIRFLOW_SECRET_ID}" \
    --region "${AWS_REGION}" \
    >/dev/null 2>&1
do
    echo "Airflow secret is not ready yet. Retrying in 5 seconds..."
    sleep 5
done

echo "Airflow secret is available."