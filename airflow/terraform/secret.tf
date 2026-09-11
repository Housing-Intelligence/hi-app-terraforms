resource "aws_secretsmanager_secret_version" "airflow" {
  secret_id = aws_secretsmanager_secret.airflow.id
  recovery_window_in_days = 0

  secret_string = jsonencode({
    rds = {
      host     = aws_db_instance.airflow_db.address
      port     = aws_db_instance.airflow_db.port
      database = var.db_name
      username = var.db_username
      password = random_password.db.result
    }

    # redis = {
    #   host     = aws_elasticache_replication_group.airflow_redis.primary_endpoint_address
    #   port     = aws_elasticache_replication_group.airflow_redis.port
    #   password = random_password.redis.result
    # }

    airflow = {
      fernet_key  = random_id.airflow_fernet.b64_url
      jwt_secret  = random_password.airflow_jwt.result
      api_secret_key = random_password.airflow_api_secret.result

      admin_username  = "admin"
      admin_firstname = "Airflow"
      admin_lastname  = "Admin"
      admin_email     = "admin@example.com"
      admin_password  = var.airflow_admin_pw
    }
  })
}