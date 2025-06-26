# modules/ecs/main.tf

# ECS Cluster
resource "aws_ecs_cluster" "mercado_cluster" {
  name = "${var.environment}-mercado-scraper-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

# Use existing IAM roles from AWS Learner Lab
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Local values for common configurations
locals {
  # Function 4: merge for combining tags
  common_tags = merge(
    var.default_tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "mercado-scraper"
    }
  )
  logout_uri = "https://${var.cognito_domain}.auth.${var.aws_region}.amazoncognito.com/logout?client_id=${var.cognito_client_id}&logout_uri=http://${aws_lb.external.dns_name}"
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.environment}-mercado-ecs-tasks"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  # Allow External ALB to reach frontend containers on port 80
  ingress {
    description     = "External ALB to frontend containers"
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [aws_security_group.external_alb.id]
  }

  # Allow Internal NLB to reach backend containers on port 8000
  ingress {
    description = "Internal NLB to backend containers"
    protocol    = "tcp"
    from_port   = 8000
    to_port     = 8000
    cidr_blocks = var.private_subnet_cidrs  # NLB doesn't have security groups
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.environment}-mercado-backend"
  retention_in_days = 7
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "scraper" {
  name              = "/ecs/${var.environment}-mercado-scraper"
  retention_in_days = 7
  tags              = local.common_tags
}

# Backend Task Definition
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.environment}-mercado-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name  = "backend"
      image = var.backend_image
      essential = true
      
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "DATABASE_URL"
          value = var.database_url
        },
        {
          name  = "PYTHONUNBUFFERED"
          value = "1"
        },
        {
          name  = "SCRAPER_URL"
          value = "http://mercado-scraper:8001"
        },
        {
          name  = "COGNITO_POOL_ID"
          value = var.cognito_pool_id
        },
        {
          name  = "COGNITO_CLIENT_ID"
          value = var.cognito_client_id
        },
        {
          name  = "COGNITO_REGION"
          value = var.aws_region
        },
        {
          name  = "COGNITO_DOMAIN"
          value = var.cognito_domain
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# Scraper Task Definition
resource "aws_ecs_task_definition" "scraper_task" {
  family                   = "${var.environment}-mercado-scraper-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name  = "mercado-scraper"
      image = var.scraper_image
      essential = true
      portMappings = [
        {
          containerPort = 8001
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DATABASE_URL"
          value = var.database_url
        },
        {
          name  = "PYTHONUNBUFFERED"
          value = "1"
        },
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        },
        {
          name  = "SQS_REGION"
          value = var.sqs_region
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.scraper.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ===== EXTERNAL APPLICATION LOAD BALANCER (PUBLIC) =====
resource "aws_lb" "external" {
  name               = "${var.environment}-mercado-external-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.external_alb.id]
  subnets           = var.public_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.environment}-mercado-external-alb"
    Type = "External"
  })
}

# External ALB Security Group
resource "aws_security_group" "external_alb" {
  name        = "${var.environment}-mercado-external-alb"
  description = "Security group for external ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-mercado-external-alb"
  })
}

###############################################################################
# 1. Pick deterministic private IPs in each private subnet (.10 address)
###############################################################################
locals {
  nlb_private_ips = [
    for cidr in var.private_subnet_cidrs : cidrhost(cidr, 10)
  ]
}

###############################################################################
# 2. Build the NLB with those deterministic private IPs
###############################################################################
resource "aws_lb" "internal" {
  name               = "${var.environment}-mercado-internal-nlb"
  internal           = true
  load_balancer_type = "network"

  dynamic "subnet_mapping" {
    for_each = zipmap(var.private_subnet_ids, local.nlb_private_ips)
    content {
      subnet_id            = subnet_mapping.key
      private_ipv4_address = subnet_mapping.value
    }
  }

  tags = merge(local.common_tags, { Type = "Internal" })
}

# ===== TARGET GROUPS =====

# Frontend Target Group (for External ALB)
resource "aws_lb_target_group" "frontend" {
  name        = "${var.environment}-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = local.common_tags
}

# Backend Target Group (for Internal NLB)
resource "aws_lb_target_group" "backend_nlb" {
  name        = "${var.environment}-backend-nlb-tg"
  port        = 8000
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    protocol            = "TCP"
    interval            = 30
  }

  tags = local.common_tags
}

# Proxy Target Group for NLB (targets the NLB from ALB)
resource "aws_lb_target_group" "nlb_proxy" {
  name        = "${var.environment}-nlb-proxy-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/api/health"
    matcher             = "200"
  }

  tags = local.common_tags
}

# ===== LISTENERS =====

# External ALB Listener
resource "aws_lb_listener" "external" {
  load_balancer_arn = aws_lb.external.arn
  port              = "80"
  protocol          = "HTTP"
  default_action { # do nothing
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "404"
    }
  }
}


# Internal NLB Listener (port 80 -> 8000)
resource "aws_lb_listener" "internal" {
  load_balancer_arn = aws_lb.internal.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_nlb.arn
  }
}

# ===== ALB ROUTING RULES =====

# Route /api/* to Internal NLB
resource "aws_lb_listener_rule" "api_proxy" {
  listener_arn = aws_lb_listener.external.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_proxy.arn
  }

  condition {
    path_pattern { values = ["/api/*"] }
  }
}

###############################################################################
# 3. Attach those known private IPs to the ALB target group
###############################################################################
resource "aws_lb_target_group_attachment" "nlb_to_alb" {
  for_each         = toset(local.nlb_private_ips)      # use private IPs as keys (known at plan time)
  target_group_arn = aws_lb_target_group.nlb_proxy.arn
  target_id        = each.value                        # the private IP of the NLB node
  port             = 80
}

# ===== ECS SERVICES =====

# Backend Service
resource "aws_ecs_service" "backend" {
  count           = var.backend_replicas > 0 ? 1 : 0
  name            = "${var.environment}-mercado-backend-service"
  cluster         = aws_ecs_cluster.mercado_cluster.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_replicas
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id, var.db_access_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_nlb.arn
    container_name   = "backend"
    container_port   = 8000
  }

  health_check_grace_period_seconds = 60

  depends_on = [aws_lb_listener.internal]

  tags = local.common_tags
}


# Scraper Service
resource "aws_ecs_service" "scraper" {
  count           = var.scraper_replicas > 0 ? 1 : 0
  name            = "${var.environment}-mercado-scraper-service"
  cluster         = aws_ecs_cluster.mercado_cluster.id
  task_definition = aws_ecs_task_definition.scraper_task.arn
  desired_count   = var.scraper_replicas
  
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 0
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id, var.db_access_sg_id]
    assign_public_ip = false
  }
}