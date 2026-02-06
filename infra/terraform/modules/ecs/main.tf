# BetterBooks ECS Module
# Creates ECS Fargate cluster, services, and supporting resources

# ECR Repositories
resource "aws_ecr_repository" "api_gateway" {
  name                 = "${var.project_name}-api-gateway"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-api-gateway"
  }
}

resource "aws_ecr_repository" "llm_gateway" {
  name                 = "${var.project_name}-llm-gateway"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-llm-gateway"
  }
}

# ECR Lifecycle Policy (keep last 10 images)
resource "aws_ecr_lifecycle_policy" "api_gateway" {
  repository = aws_ecr_repository.api_gateway.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "llm_gateway" {
  repository = aws_ecr_repository.llm_gateway.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "disabled"  # Enable for production monitoring
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-cluster"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/ecs/${var.project_name}-${var.environment}/api-gateway"
  retention_in_days = 7  # Minimal retention for cost savings

  tags = {
    Name = "${var.project_name}-api-gateway-logs"
  }
}

resource "aws_cloudwatch_log_group" "llm_gateway" {
  name              = "/ecs/${var.project_name}-${var.environment}/llm-gateway"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-llm-gateway-logs"
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-${var.environment}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ecs-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Tasks
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-${var.environment}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-role"
  }
}

# S3 access policy for ECS tasks
resource "aws_iam_role_policy" "ecs_task_s3" {
  name = "${var.project_name}-${var.environment}-s3-access"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

# Secrets Manager access policy for ECS tasks
resource "aws_iam_role_policy" "ecs_task_secrets" {
  name = "${var.project_name}-${var.environment}-secrets-access"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.secrets_arn
      }
    ]
  })
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false  # Enable for production

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# ALB Target Group for API Gateway
resource "aws_lb_target_group" "api_gateway" {
  name        = "${var.project_name}-${var.environment}-api"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-api-gateway-tg"
  }
}

# ALB Target Group for LLM Gateway
resource "aws_lb_target_group" "llm_gateway" {
  name        = "${var.project_name}-${var.environment}-llm"
  port        = 8002
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-llm-gateway-tg"
  }
}

# ALB Listener (HTTP - add HTTPS for production)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }
}

# Listener Rule for LLM Gateway (/complete, /llm/*)
resource "aws_lb_listener_rule" "llm_gateway" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.llm_gateway.arn
  }

  condition {
    path_pattern {
      values = ["/complete", "/complete/*", "/llm/*"]
    }
  }
}

# ECS Task Definition - API Gateway
resource "aws_ecs_task_definition" "api_gateway" {
  family                   = "${var.project_name}-${var.environment}-api-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.api_gateway_cpu
  memory                   = var.api_gateway_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "api-gateway"
      image = var.api_gateway_image != "" ? var.api_gateway_image : "${aws_ecr_repository.api_gateway.repository_url}:latest"

      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "ENVIRONMENT", value = "production" },
        { name = "DATABASE_URL", value = var.database_url },
        { name = "REDIS_URL", value = var.redis_url },
        { name = "AWS_S3_BUCKET_NAME", value = var.s3_bucket_name },
        { name = "AWS_SECRET_NAME", value = "${var.project_name}/${var.environment}" },
        { name = "AWS_REGION", value = data.aws_region.current.name },
        { name = "STORAGE_BACKEND", value = "s3" },
        { name = "LLM_GATEWAY_URL", value = "http://localhost:8002" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api_gateway.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-api-gateway-task"
  }
}

# ECS Task Definition - LLM Gateway
resource "aws_ecs_task_definition" "llm_gateway" {
  family                   = "${var.project_name}-${var.environment}-llm-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.llm_gateway_cpu
  memory                   = var.llm_gateway_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "llm-gateway"
      image = var.llm_gateway_image != "" ? var.llm_gateway_image : "${aws_ecr_repository.llm_gateway.repository_url}:latest"

      portMappings = [
        {
          containerPort = 8002
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "ENVIRONMENT", value = "production" },
        { name = "AWS_SECRET_NAME", value = "${var.project_name}/${var.environment}" },
        { name = "AWS_REGION", value = data.aws_region.current.name }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.llm_gateway.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8002/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-llm-gateway-task"
  }
}

# ECS Service - API Gateway
resource "aws_ecs_service" "api_gateway" {
  name            = "${var.project_name}-${var.environment}-api-gateway"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_gateway.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_gateway.arn
    container_name   = "api-gateway"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = "${var.project_name}-api-gateway-service"
  }
}

# ECS Service - LLM Gateway
resource "aws_ecs_service" "llm_gateway" {
  name            = "${var.project_name}-${var.environment}-llm-gateway"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.llm_gateway.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.llm_gateway.arn
    container_name   = "llm-gateway"
    container_port   = 8002
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = "${var.project_name}-llm-gateway-service"
  }
}

# Data source for current region
data "aws_region" "current" {}
