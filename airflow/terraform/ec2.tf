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

resource "aws_vpc_security_group_ingress_rule" "airflow_ui" {
  security_group_id = aws_security_group.airflow_ec2_sg.id

  cidr_ipv4   = "123.90.9.0/24"
  from_port   = 8080
  to_port     = 8080
  ip_protocol = "tcp"
}
  
resource "aws_instance" "airflow" {
  ami           = var.airflow_ami_id
  instance_type = var.ec2_parameters["instance_type"]

  subnet_id = var.public_subnet_ids[0]

  associate_public_ip_address = true

  key_name = "test"

  vpc_security_group_ids = [
    aws_security_group.airflow_ec2_sg.id
  ]

  root_block_device {
    volume_size           = var.ec2_parameters["root_volume_size"]
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  iam_instance_profile = data.aws_iam_instance_profile.airflow.name

  user_data = <<-EOF
    #!/bin/bash

    set -euo pipefail

    echo 'ec2-user:MyTempPassword123!' | chpasswd

    # Create Airflow configuration directory
    mkdir -p /etc/airflow

    # Provide runtime configuration for systemd services
    {
        printf '\n'
        printf 'AIRFLOW_SECRET_ID=%s\n' '${aws_secretsmanager_secret.airflow.id}'
        printf 'AIRFLOW_IMAGE_TAG=%s\n' '${var.airflow_image_tag}'
        printf 'AWS_REGION=%s\n' '${var.aws_region}'
    } >> /etc/airflow/airflow.conf

    chmod 600 /etc/airflow/airflow.conf

    # Reload systemd and start Airflow
    systemctl daemon-reload
    systemctl start wait-for-password.service
  EOF

  tags = {
    Name        = "airflow-${var.workspace}"
    Environment = var.workspace
  }
}
