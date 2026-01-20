# ---------------------------------------------------------
# ALB
# ---------------------------------------------------------
#tfsec:ignore:aws-elb-alb-not-public
resource "aws_lb" "api" {
  name                             = "${local.product}-${local.env}-api-alb"
  load_balancer_type               = "application"
  internal                         = false
  security_groups                  = [aws_security_group.api_alb.id]
  subnets                          = aws_subnet.public[*].id
  idle_timeout                     = 60
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = false
  enable_http2                     = true
  drop_invalid_header_fields       = true

  tags = {
    Name = "${local.product}-${local.env}-api-alb"
  }
}

resource "aws_lb_listener" "api_https" {
  load_balancer_arn = aws_lb.api.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# ---------------------------------------------------------
# ALB-SG
# ---------------------------------------------------------
resource "aws_security_group" "api_alb" {
  name   = "${local.product}-${local.env}-api-alb-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.product}-${local.env}-api-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "api_alb_https" {
  security_group_id = aws_security_group.api_alb.id
  description       = "Allow from CloudFront"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "api_alb_to_all" {
  security_group_id = aws_security_group.api_alb.id
  description       = "Allow to All"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------------------------------------------------------
# Target Group
# ---------------------------------------------------------
#tfsec:ignore:aws-elb-alb-not-public:
resource "aws_lb_target_group" "api" {
  name     = "${local.product}-${local.env}-api-tg"
  vpc_id   = aws_vpc.main.id
  port     = 80
  protocol = "HTTP"
  # protocol_version = "HTTP2"
  target_type = "ip"

  health_check {
    enabled             = true
    port                = "traffic-port"
    path                = "/"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${local.product}-${local.env}-api-alb"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------
# ECS-タスク定義
# ---------------------------------------------------------
data "aws_ecs_task_definition" "api" {
  task_definition = aws_ecs_task_definition.api.family
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${local.product}-${local.env}-api-ecs-task-definition"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.api_ecs_task_execution.arn
  task_role_arn            = aws_iam_role.api_ecs_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "nginx:stable-alpine"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.api_ecs.name}"
          awslogs-region        = "ap-northeast-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# ---------------------------------------------------------
# ECS-Service
# ---------------------------------------------------------
resource "aws_ecs_service" "api" {
  name                   = "${local.product}-${local.env}-api-ecs-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = data.aws_ecs_task_definition.api.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  platform_version       = "1.4.0"
  enable_execute_command = true

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.api_ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "nginx"
    container_port   = 80
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = null

  #  lifecycle {
  #    ignore_changes = [
  #      desired_count
  #    ]
  #  }
}

# ---------------------------------------------------------
# ECS-IAM
# ---------------------------------------------------------
# execution
resource "aws_iam_role" "api_ecs_task_execution" {
  name = "${local.product}-${local.env}-api-task-execution-role"

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
}

resource "aws_iam_role_policy_attachment" "api_ecs_task_execution" {
  for_each = toset(["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"])

  role       = aws_iam_role.api_ecs_task_execution.name
  policy_arn = each.value
}

# task
resource "aws_iam_role" "api_ecs_task" {
  name = "${local.product}-${local.env}-api-task-role"

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
}

resource "aws_iam_policy" "api_ecs_task" {
  name = "${local.product}-${local.env}-api-task-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECSExec"
        Effect = "Allow"
        Action = [
          "ssmmessages:OpenDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:CreateControlChannel"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_ecs_task" {
  role       = aws_iam_role.api_ecs_task.name
  policy_arn = aws_iam_policy.api_ecs_task.arn
}

# ---------------------------------------------------------
# ECS-SG
# ---------------------------------------------------------
resource "aws_security_group" "api_ecs" {
  name   = "${local.product}-${local.env}-api-ecs-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.product}-${local.env}-api-ecs-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "api_ecs_from_alb" {
  security_group_id            = aws_security_group.api_ecs.id
  referenced_security_group_id = aws_security_group.api_alb.id
  description                  = aws_security_group.api_alb.name
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_egress_rule" "api_ecs_to_all" {
  security_group_id = aws_security_group.api_ecs.id
  description       = "Allow to All"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------------------------------------------------------
# ECS-Log
# ---------------------------------------------------------
resource "aws_cloudwatch_log_group" "api_ecs" {
  name              = "/ecs/${local.product}/${local.env}/api"
  retention_in_days = 14
}
