#!/usr/bin/env bash

set -euo pipefail

AIRFLOW_HOME="/opt/airflow"
export AIRFLOW_HOME

ECR_REPOSITORY="${ECR_REPOSITORY:?ECR_REPOSITORY is required}"
AIRFLOW_IMAGE_TAG="${AIRFLOW_IMAGE_TAG:?AIRFLOW_IMAGE_TAG is required}"

AIRFLOW_SECRET_ID="${AIRFLOW_SECRET_ID:?AIRFLOW_SECRET_ID is required}"
export AIRFLOW_SECRET_ID

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Install Docker

install_docker() {

    log "Checking Docker..."

    if command -v docker >/dev/null 2>&1; then
        log "Docker already installed"
    else
        log "Installing Docker..."

        dnf install -y docker

        systemctl enable docker
        systemctl start docker
    fi

    if ! systemctl is-active --quiet docker; then
        log "Docker is not running"
        exit 1
    fi

    log "Docker is ready"
}

# Install dependencies

install_dependencies() {

    log "Installing dependencies..."

    dnf install -y \
        jq \
        unzip \
        curl

    log "Dependencies installed"
}

# Check AWS CLI

check_aws_cli() {

    log "Checking AWS CLI..."

    if ! command -v aws >/dev/null 2>&1; then
        log "AWS CLI is not installed"
        exit 1
    fi

    aws --version

    log "AWS CLI is available"
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

# Create Airflow Workspace

create_workspace() {

    log "Creating Airflow workspace..."

    mkdir -p \
        "${AIRFLOW_HOME}/dags" \
        "${AIRFLOW_HOME}/logs" \
        "${AIRFLOW_HOME}/plugins" \
        "${AIRFLOW_HOME}/config"

    chmod 755 "${AIRFLOW_HOME}"

    log "Airflow workspace created"
}

render_environment() {

    log "Rendering Airflow environment..."

    "${AIRFLOW_HOME}/scripts/render-env.sh"

    log "Airflow environment rendered"
}

main() {

    log "Starting Airflow EC2 bootstrap..."

    install_docker

    install_dependencies

    check_aws_cli

    get_instance_metadata

    check_aws_identity

    build_ecr_image

    create_workspace

    render_environment

    log "Airflow EC2 bootstrap completed successfully."
}

main "$@"