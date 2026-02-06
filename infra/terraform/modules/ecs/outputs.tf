# ECS Module Outputs

output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "api_gateway_ecr_url" {
  description = "ECR repository URL for API Gateway"
  value       = aws_ecr_repository.api_gateway.repository_url
}

output "llm_gateway_ecr_url" {
  description = "ECR repository URL for LLM Gateway"
  value       = aws_ecr_repository.llm_gateway.repository_url
}

output "api_gateway_service_name" {
  description = "API Gateway ECS service name"
  value       = aws_ecs_service.api_gateway.name
}

output "llm_gateway_service_name" {
  description = "LLM Gateway ECS service name"
  value       = aws_ecs_service.llm_gateway.name
}
