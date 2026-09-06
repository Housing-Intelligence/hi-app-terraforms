packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.0"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "ami_name" {
  type    = string
  default = "airflow-master"
}

source "amazon-ebs" "airflow" {

  region = var.aws_region

  ami_name = "${var.ami_name}-${formatdate("YYYYMMDD-hhmmss", timestamp())}"

  instance_type = "t3.small"

  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }

    owners      = ["amazon"]
    most_recent = true
  }

  ssh_username = "ec2-user"

  tags = {
    Name      = var.ami_name
    ManagedBy = "Packer"
  }
}

build {
  name = "airflow"

  sources = [
    "source.amazon-ebs.airflow"
  ]

  provisioner "shell" {
    inline = [
      "sudo dnf update -y",
      "sudo dnf install -y docker awscli jq unzip"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo systemctl enable docker",
      "sudo mkdir -p /opt/airflow"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /opt/airflow/scripts",
      "sudo mkdir -p /opt/airflow/dags",
      "sudo mkdir -p /opt/airflow/logs",
      "sudo mkdir -p /opt/airflow/plugins",
      "sudo mkdir -p /opt/airflow/config"
    ]
  }

  provisioner "file" {
    source      = "../docker/docker-compose.yml"
    destination = "/tmp/docker-compose.yml"
  }

  provisioner "file" {
    source      = "${path.root}/../scripts/ec2-bootstrap.sh"
    destination = "/tmp/ec2-bootstrap.sh"
  }

  provisioner "file" {
    source      = "${path.root}/../scripts/render-env.sh"
    destination = "/tmp/render-env.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/ec2-bootstrap.sh /opt/airflow/scripts/ec2-bootstrap.sh",
      "sudo mv /tmp/render-env.sh /opt/airflow/scripts/render-env.sh",
      "sudo mv /tmp/docker-compose.yml /opt/airflow/docker-compose.yml",

      "sudo chmod 755 /opt/airflow/scripts/ec2-bootstrap.sh",
      "sudo chmod 755 /opt/airflow/scripts/render-env.sh",

      "sudo chown -R root:root /opt/airflow"
    ]
  }
}