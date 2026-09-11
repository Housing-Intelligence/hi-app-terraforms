terraform {
  required_version = ">= 1.6.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
        source  = "hashicorp/random"
        version = "~> 3.5"
    }
  }
}

variable "workspace" {
  description = "The unique workspace identifier."
  type    = string
  default = "dev"
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-2"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "airflow_ami_id" {
  type = string
}

variable "airflow_image_tag" {
  type = string
}

variable "db_name" {
  type    = string
  default = "airflow"
}

variable "db_username" {
  type    = string
  default = "airflow"
}

variable "ec2_parameters" {
  type = map(string)
}

variable "pg_parameters" {
  type = map(string)
}

# variable "redis_parameters" {
#   type = map(string)
# }

variable "airflow_admin_pw" {
  type      = string
  sensitive = true
}

resource "aws_secretsmanager_secret" "airflow" {
  recovery_window_in_days = 0
  name = "airflow-${var.workspace}-secret"
}

data "aws_vpc" "existing_vpc" {
    id = var.vpc_id
}

data "aws_iam_instance_profile" "airflow" {
  name = "airflow-ec2-instance-profile"
}

resource "random_id" "airflow_fernet" {
  byte_length = 32
}

resource "random_password" "airflow_jwt" {
  length  = 64
  special = false
}

resource "random_password" "airflow_api_secret" {
  length  = 64
  special = false
}