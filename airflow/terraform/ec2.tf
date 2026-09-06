resource "aws_security_group" "airflow_ec2_sg" {
  name    = "airflow-${var.workspace}-sg"
  description = "Security group for Airflow EC2 instance"
  vpc_id = data.aws_vpc.existing_vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "airflow-${var.workspace}-sg"
    Environment = var.workspace
  }
}
  
resource "aws_instance" "airflow" {
  ami           = var.airflow_ami_id
  instance_type = var.ec2_parameters["instance_type"]

  subnet_id = var.private_subnet_ids[0]

  vpc_security_group_ids = [
    aws_security_group.airflow_ec2_sg.id
  ]

  iam_instance_profile = data.aws_iam_instance_profile.airflow.name

  user_data = <<-EOF
    #!/bin/bash

    set -euo pipefail

    export AIRFLOW_SECRET_ID="${aws_secretsmanager_secret.airflow.id}"
    export AIRFLOW_IMAGE="${var.airflow_ecr_repository_url}:${var.airflow_image_tag}"
    export AWS_REGION="${var.aws_region}"

    /opt/airflow/scripts/ec2-bootstrap.sh
  EOF

  tags = {
    Name        = "airflow-${var.workspace}"
    Environment = var.workspace
  }
}
