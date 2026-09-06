resource "aws_elasticache_subnet_group" "airflow_redis_subnet_group" {
  name       = "airflow-redis-${var.workspace}"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "redis_sg" {
  name        = "airflow-${var.workspace}-redis-sg"
  description = "Security group for Airflow Redis instance"
  vpc_id      = data.aws_vpc.existing_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "airflow-redis-${var.workspace}"
    Environment = var.workspace
  }
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_airflow" {
  security_group_id            = aws_security_group.redis_sg.id
  referenced_security_group_id = aws_security_group.airflow_ec2_sg.id

  from_port   = 6379
  to_port     = 6379
  ip_protocol = "tcp"
}

resource "aws_elasticache_replication_group" "airflow_redis" {
    replication_group_id          = "airflow-redis-${var.workspace}"
    replication_group_description = "Redis replication group for Airflow"

    engine            = "redis"
    engine_version    = "7.1"

    node_type         = var.redis_parameters["node_type"]
    num_cache_clusters = var.redis_parameters["number_cache_clusters"]
    port              = 6379

    subnet_group_name = aws_elasticache_subnet_group.airflow_redis_subnet_group.name
    security_group_ids = [aws_security_group.redis_sg.id]

    multi_az_enabled = false
    automatic_failover_enabled = false
    at_rest_encryption_enabled = true
    transit_encryption_enabled = true

    auth_token = random_password.redis.result

    tags = {
        Name        = "airflow-redis-${var.workspace}"
        Environment = var.workspace
    }
}

resource "random_password" "redis" {
  length  = 32
  special = false
}