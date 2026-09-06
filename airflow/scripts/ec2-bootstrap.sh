#!/usr/bin/env bash

set -euo pipefail

AIRFLOW_HOME="/opt/airflow"
export AIRFLOW_HOME

AIRFLOW_IMAGE_TAG="${AIRFLOW_IMAGE_TAG:?AIRFLOW_IMAGE_TAG is required}"
AIRFLOW_SECRET_ID="${AIRFLOW_SECRET_ID:?AIRFLOW_SECRET_ID is required}"
export AIRFLOW_SECRET_ID

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Get EC2 Metadata

get_instance_metadata() {

    log "Getting EC2 metadata..."

    IMDS_TOKEN=$(curl -sS -X PUT \
        "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

    IDENTITY_DOCUMENT=$(curl -sS \
        -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" \
        "http://169.254.169.254/latest/dynamic/instance-identity/document")

    AWS_REGION=$(echo "${IDENTITY_DOCUMENT}" | jq -r '.region')
    AWS_ACCOUNT_ID=$(echo "${IDENTITY_DOCUMENT}" | jq -r '.accountId')
    INSTANCE_ID=$(echo "${IDENTITY_DOCUMENT}" | jq -r '.instanceId')

    export AWS_REGION
    export AWS_ACCOUNT_ID
    export INSTANCE_ID

    log "Region: ${AWS_REGION}"
    log "Account: ${AWS_ACCOUNT_ID}"
    log "Instance ID: ${INSTANCE_ID}"
}

# Build ECR Image
build_ecr_image() {

    ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    ECR_REPOSITORY="airflow"

    AIRFLOW_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}:${AIRFLOW_IMAGE_TAG}"

    export AIRFLOW_IMAGE

    log "ECR Registry: ${ECR_REGISTRY}"
    log "Airflow Image: ${AIRFLOW_IMAGE}"
}

# Check AWS Identity

check_aws_identity() {

    log "Checking AWS identity..."

    aws sts get-caller-identity

    log "AWS identity check passed"
}

render_environment() {

    log "Rendering Airflow environment..."

    "${AIRFLOW_HOME}/scripts/render-env.sh"

    log "Airflow environment rendered"
}

main() {

    log "Starting Airflow EC2 bootstrap..."

    get_instance_metadata

    check_aws_identity

    build_ecr_image

    render_environment

    log "Airflow EC2 bootstrap completed successfully."
}

main "$@"