# BetterBooks Terraform Variables - Development Environment

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "betterbooks"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "dev"
}

# Networking
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Database
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"  # Free tier eligible
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS (GB)"
  type        = number
  default     = 20  # Free tier: 20GB
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "betterbooks"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

# Secrets
variable "jwt_secret_key" {
  description = "JWT secret key for authentication"
  type        = string
  sensitive   = true
}

# Container Images
variable "api_gateway_image" {
  description = "Docker image for API Gateway"
  type        = string
  default     = ""  # Will use ECR URL after first push
}

variable "llm_gateway_image" {
  description = "Docker image for LLM Gateway"
  type        = string
  default     = ""  # Will use ECR URL after first push
}

# Fargate Sizing (Cost-optimized)
variable "api_gateway_cpu" {
  description = "CPU units for API Gateway (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "api_gateway_memory" {
  description = "Memory for API Gateway (MB)"
  type        = number
  default     = 512
}

variable "llm_gateway_cpu" {
  description = "CPU units for LLM Gateway"
  type        = number
  default     = 512
}

variable "llm_gateway_memory" {
  description = "Memory for LLM Gateway (MB)"
  type        = number
  default     = 1024
}

# Redis (optional - can skip for minimal cost)
variable "redis_url" {
  description = "Redis URL for caching (leave empty to disable)"
  type        = string
  default     = ""
}
