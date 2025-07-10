# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs.name
      }
    }
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# ECS Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = var.enable_spot_instances ? ["FARGATE", "FARGATE_SPOT"] : ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = var.enable_spot_instances ? 0 : 100
    capacity_provider = "FARGATE"
  }

  dynamic "default_capacity_provider_strategy" {
    for_each = var.enable_spot_instances ? [1] : []
    content {
      base              = 0
      weight            = 100
      capacity_provider = "FARGATE_SPOT"
    }
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-logs"
  }
}

# Task Definition
resource "aws_ecs_task_definition" "n8n" {
  family                   = "${var.project_name}-task"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = var.ecs_cpu
  memory                  = var.ecs_memory
  execution_role_arn      = aws_iam_role.ecs_execution.arn
  task_role_arn          = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "n8n"
      image = var.n8n_image
      
      portMappings = [
        {
          containerPort = 5678
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "N8N_HOST"
          value = var.domain_name != "" ? var.domain_name : aws_lb.main.dns_name
        },
        {
          name  = "N8N_PROTOCOL"
          value = var.certificate_arn != "" ? "https" : "http"
        },
        {
          name  = "N8N_PORT"
          value = "5678"
        },
        {
          name  = "WEBHOOK_URL"
          value = var.certificate_arn != "" ? "https://${var.domain_name != "" ? var.domain_name : aws_lb.main.dns_name}/" : "http://${aws_lb.main.dns_name}/"
        },
        {
          name  = "GENERIC_TIMEZONE"
          value = "America/Sao_Paulo"
        },
        {
          name  = "DB_TYPE"
          value = "postgresdb"
        },
        {
          name  = "DB_POSTGRESDB_HOST"
          value = aws_db_instance.main.endpoint
        },
        {
          name  = "DB_POSTGRESDB_PORT"
          value = "5432"
        },
        {
          name  = "DB_POSTGRESDB_DATABASE"
          value = var.db_name
        },
        {
          name  = "N8N_METRICS"
          value = "true"
        },
        {
          name  = "N8N_DIAGNOSTICS_ENABLED"
          value = "false"
        },
        {
          name  = "N8N_LOG_LEVEL"
          value = "warn"
        }
      ]
      
      secrets = [
        {
          name      = "N8N_BASIC_AUTH_USER"
          valueFrom = aws_secretsmanager_secret.n8n_auth_user.arn
        },
        {
          name      = "N8N_BASIC_AUTH_PASSWORD"
          valueFrom = aws_secretsmanager_secret.n8n_auth_password.arn
        },
        {
          name      = "N8N_ENCRYPTION_KEY"
          valueFrom = aws_secretsmanager_secret.n8n_encryption_key.arn
        },
        {
          name      = "DB_POSTGRESDB_USER"
          valueFrom = aws_secretsmanager_secret.db_username.arn
        },
        {
          name      = "DB_POSTGRESDB_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db_password.arn
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      healthCheck = {
        command = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:5678/healthz || exit 1"]
        interval = 30
        timeout = 5
        retries = 3
        startPeriod = 60
      }
      
      essential = true
    }
  ])

  tags = {
    Name = "${var.project_name}-task"
  }
}

# ECS Service
resource "aws_ecs_service" "n8n" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.n8n.arn
  desired_count   = var.min_capacity

  capacity_provider_strategy {
    capacity_provider = var.enable_spot_instances ? "FARGATE_SPOT" : "FARGATE"
    weight           = var.enable_spot_instances ? 100 : 100
    base             = var.enable_spot_instances ? 0 : 1
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.enable_spot_instances ? [1] : []
    content {
      capacity_provider = "FARGATE"
      weight           = 0
      base             = 1
    }
  }

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets         = aws_subnet.private[*].id
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.n8n.arn
    container_name   = "n8n"
    container_port   = 5678
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener.https,
    aws_lb_listener.http_dev
  ]

  tags = {
    Name = "${var.project_name}-service"
  }
}
