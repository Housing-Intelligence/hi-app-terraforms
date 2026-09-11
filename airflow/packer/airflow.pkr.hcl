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

variable "subnet_id" {
  type = string
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

  subnet_id = var.subnet_id

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

      # Docker and other utilities
      "sudo dnf install -y ec2-instance-connect docker awscli jq unzip",

      # Start Docker and enable it on boot
      "sudo systemctl enable --now docker",
      
      "sudo systemctl enable ec2-instance-connect",

      # Install Docker Compose CLI plugin
      "sudo mkdir -p /usr/local/lib/docker/cli-plugins",

      "sudo curl -SL https://github.com/docker/compose/releases/download/v2.39.2/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose",

      "sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose",

      # Verify installations
      "docker --version",
      "docker compose version",
      "aws --version",
      "jq --version"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /opt/airflow",
      "sudo mkdir -p /etc/airflow",
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

  provisioner "file" {
    source      = "${path.root}/../scripts/wait-for-password.sh"
    destination = "/tmp/wait-for-password.sh"
  }

  provisioner "file" {
    source      = "${path.root}/../scripts/wait-for-password.service"
    destination = "/tmp/wait-for-password.service"
  }

  provisioner "file" {
    source      = "${path.root}/../scripts/airflow-docker.service"
    destination = "/tmp/airflow-docker.service"
  }

  provisioner "file" {
    source      = "${path.root}/../scripts/startup.service"
    destination = "/tmp/startup.service"
  }
  
  provisioner "file" {
    source      = "${path.root}/../configs/airflow.conf"
    destination = "/tmp/airflow.conf"
  }

  provisioner "shell" {
    inline = [
      # Airflow scripts
      "sudo mv /tmp/ec2-bootstrap.sh /opt/airflow/scripts/ec2-bootstrap.sh",
      "sudo mv /tmp/render-env.sh /opt/airflow/scripts/render-env.sh",
      "sudo mv /tmp/wait-for-password.sh /opt/airflow/scripts/wait-for-password.sh",

      # Docker Compose
      "sudo mv /tmp/docker-compose.yml /opt/airflow/docker-compose.yml",

      # Airflow configuration
      "sudo mv /tmp/airflow.conf /etc/airflow/airflow.conf",

      # Systemd services
      "sudo mv /tmp/wait-for-password.service /etc/systemd/system/wait-for-password.service",
      "sudo mv /tmp/startup.service /etc/systemd/system/startup.service",
      "sudo mv /tmp/airflow-docker.service /etc/systemd/system/airflow-docker.service",

      # Permissions
      "sudo chmod 755 /opt/airflow/scripts/ec2-bootstrap.sh",
      "sudo chmod 755 /opt/airflow/scripts/render-env.sh",
      "sudo chmod 755 /opt/airflow/scripts/wait-for-password.sh",

      # Ownership
      "sudo chown -R root:root /opt/airflow",

      # Reload systemd
      "sudo systemctl daemon-reload",
      "sudo systemctl enable wait-for-password.service",
      "sudo systemctl enable startup.service",
      "sudo systemctl enable airflow-docker.service"
    ]
  }
}