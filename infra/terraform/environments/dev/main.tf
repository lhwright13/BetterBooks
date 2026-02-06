# BetterBooks AWS Infrastructure - Development Environment
# Cost-optimized for showcase project (~$30-50/month)

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment for remote state (recommended for team/production)
  # backend "s3" {
  #   bucket         = "betterbooks-terraform-state"
  #   key            = "dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "BetterBooks"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Networking Module - VPC, Subnets, Security Groups
module "networking" {
  source = "../../modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

# Secrets Module - AWS Secrets Manager
module "secrets" {
  source = "../../modules/secrets"

  project_name   = var.project_name
  environment    = var.environment
  jwt_secret_key = var.jwt_secret_key
}

# Database Module - RDS PostgreSQL
module "database" {
  source = "../../modules/database"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  db_security_group_id = module.networking.db_security_group_id

  db_instance_class   = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_username         = var.db_username
  db_password         = var.db_password
}

# Storage Module - S3 Buckets
module "storage" {
  source = "../../modules/storage"

  project_name = var.project_name
  environment  = var.environment
}

# ECS Module - Fargate Services
module "ecs" {
  source = "../../modules/ecs"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  ecs_security_group_id = module.networking.ecs_security_group_id
  alb_security_group_id = module.networking.alb_security_group_id

  # Container configuration
  api_gateway_image = var.api_gateway_image
  llm_gateway_image = var.llm_gateway_image

  # Environment variables for containers
  database_url      = module.database.connection_string
  redis_url         = var.redis_url
  s3_bucket_name    = module.storage.audiobooks_bucket_name
  secrets_arn       = module.secrets.secret_arn

  # Fargate sizing (cost-optimized)
  api_gateway_cpu    = var.api_gateway_cpu
  api_gateway_memory = var.api_gateway_memory
  llm_gateway_cpu    = var.llm_gateway_cpu
  llm_gateway_memory = var.llm_gateway_memory
}

# Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.ecs.alb_dns_name
}

output "api_gateway_url" {
  description = "URL for the API Gateway service"
  value       = "http://${module.ecs.alb_dns_name}"
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.database.endpoint
  sensitive   = true
}

output "s3_bucket_name" {
  description = "S3 bucket for audiobooks"
  value       = module.storage.audiobooks_bucket_name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs for Docker images"
  value = {
    api_gateway = module.ecs.api_gateway_ecr_url
    llm_gateway = module.ecs.llm_gateway_ecr_url
  }
}
