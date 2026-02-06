# BetterBooks Database Module
# Creates RDS PostgreSQL instance with pgvector support

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# Parameter Group for PostgreSQL with pgvector
resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-${var.environment}-pg15"
  family = "postgres15"

  # Enable pgvector extension loading
  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-pg-params"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-db"

  # Engine configuration
  engine               = "postgres"
  engine_version       = "15.4"
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  storage_type         = "gp2"
  storage_encrypted    = true

  # Database configuration
  db_name  = "betterbooks"
  username = var.db_username
  password = var.db_password

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_security_group_id]
  publicly_accessible    = false

  # Parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  # Backup configuration (free tier: no multi-AZ)
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"

  # Performance and monitoring
  performance_insights_enabled = false  # Costs extra
  monitoring_interval         = 0       # Disable enhanced monitoring

  # Deletion protection (enable for production)
  deletion_protection = false
  skip_final_snapshot = true

  # Auto minor version upgrades
  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.project_name}-${var.environment}-db"
  }
}
