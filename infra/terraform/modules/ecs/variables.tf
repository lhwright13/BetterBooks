# ECS Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

# Container images
variable "api_gateway_image" {
  description = "Docker image for API Gateway"
  type        = string
  default     = ""
}

variable "llm_gateway_image" {
  description = "Docker image for LLM Gateway"
  type        = string
  default     = ""
}

# Environment variables
variable "database_url" {
  description = "PostgreSQL connection string"
  type        = string
  sensitive   = true
}

variable "redis_url" {
  description = "Redis connection string"
  type        = string
  default     = ""
}

variable "s3_bucket_name" {
  description = "S3 bucket name for audiobooks"
  type        = string
}

variable "secrets_arn" {
  description = "ARN of Secrets Manager secret"
  type        = string
}

# Fargate sizing
variable "api_gateway_cpu" {
  description = "CPU units for API Gateway"
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
