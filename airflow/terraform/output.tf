output "airflow_instance_id" {
  value = aws_instance.airflow.id
}

output "airflow_private_ip" {
  value = aws_instance.airflow.private_ip
}

output "rds_endpoint" {
  value = aws_db_instance.airflow_db.endpoint
}

output "rds_port" {
  value = aws_db_instance.airflow_db.port
}

output "redis_endpoint" {
  value = aws_elasticache_replication_group.airflow_redis.primary_endpoint_address
}

output "redis_port" {
  value = 6379
}

output "airflow_secret_arn" {
  value = aws_secretsmanager_secret.airflow.arn
}