resource "aws_security_group" "rds" {
  name   = "mercado-rds-${var.environment}"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = compact([var.ecs_tasks_sg_id, var.lambda_sg_id])
    description     = "Fargate backend and Lambda to Postgres"
  }

  # Allow the RDS Proxy (which will share this SG) to connect back to the DB as well
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
    description = "Allow entities with the same SG (e.g., RDS Proxy)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "mercado-rds-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_db_instance" "postgres" {
  identifier         = "mercado-${var.environment}"
  engine             = "postgres"
  instance_class     = var.instance_class
  allocated_storage  = 20
  db_name            = "${var.environment}_db"
  username           = "clouduser"
  password           = var.db_password
  db_subnet_group_name    = var.db_subnet_group
  vpc_security_group_ids  = [aws_security_group.rds.id]
  publicly_accessible = false
  skip_final_snapshot = true
  multi_az = var.environment == "prod" ? true : false  # Multi-AZ only for prod

  tags = {
    Name        = "mercado-${var.environment}"
    Environment = var.environment
  }

  # Lifecycle meta-argument to prevent accidental destruction
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [password]
  }
}

# -----------------------------
# Secrets Manager – database master creds
# -----------------------------

resource "aws_secretsmanager_secret" "db_creds" {
  name = "mercado-${var.environment}-db-credentials"
  tags = {
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_creds_version" {
  secret_id = aws_secretsmanager_secret.db_creds.id

  secret_string = jsonencode({
    username = aws_db_instance.postgres.username
    password = var.db_password
  })
}

# Use existing LabRole for RDS Proxy auth
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# -----------------------------
# RDS Proxy
# -----------------------------
resource "aws_db_proxy" "postgres_proxy" {
  name                   = "mercado-${var.environment}-proxy"
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  debug_logging          = false
  require_tls            = true
  role_arn               = data.aws_iam_role.lab_role.arn
  vpc_security_group_ids = [aws_security_group.rds.id]
  vpc_subnet_ids         = var.private_subnet_ids

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.db_creds.arn
    iam_auth    = "DISABLED"
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_db_proxy_target" "postgres_target" {
  db_proxy_name         = aws_db_proxy.postgres_proxy.name
  target_group_name     = "default"
  db_instance_identifier = aws_db_instance.postgres.identifier
}

# -----------------------------
# Outputs
# -----------------------------

output "proxy_endpoint" {
  description = "Hostname for the RDS Proxy"
  value       = aws_db_proxy.postgres_proxy.endpoint
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "database_url" {
  description = "PostgreSQL connection URL via the RDS Proxy"
  value       = "postgresql+psycopg2://${aws_db_instance.postgres.username}:${aws_db_instance.postgres.password}@${aws_db_proxy.postgres_proxy.endpoint}/${aws_db_instance.postgres.db_name}"
  sensitive   = true
}