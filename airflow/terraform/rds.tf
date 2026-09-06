resource "aws_db_subnet_group" "airflow_db_subnet_group" {
  name       = "airflow-${var.workspace}-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "airflow-${var.workspace}-db-subnet-group"
    Environment = var.workspace
  }
}

resource "aws_security_group" "airflow_db_sg" {
  name        = "airflow-${var.workspace}-db-sg"
  description = "Security group for Airflow RDS instance"
  vpc_id      = data.aws_vpc.existing_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "airflow-rds-${var.workspace}"
    Environment = var.workspace
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_airflow" {
  security_group_id = aws_security_group.airflow_db_sg.id
  referenced_security_group_id = aws_security_group.airflow_ec2_sg.id

  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"
}

resource "aws_db_instance" "airflow_db" {
  identifier              = "airflow-${var.workspace}-db"

  engine                  = "postgres"
  engine_version          = "17"

  allocated_storage       = var.pg_parameters["allocated_storage"]
  storage_type            = var.pg_parameters["storage_type"]
  max_allocated_storage   = var.pg_parameters["max_allocated_storage"]
  instance_class          = var.pg_parameters["instance_class"]
  
  db_name                 = var.db_name
  username                = var.db_username
  password = random_password.db.result

  port                    = 5432
  db_subnet_group_name    = aws_db_subnet_group.airflow_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.airflow_db_sg.id]

  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 7
  deletion_protection     = false
  storage_encrypted       = true

  tags = {
    Name        = "airflow-rds-${var.workspace}"
    Environment = var.workspace
  }
}

resource "random_password" "db" {
  length  = 32
  special = false
}