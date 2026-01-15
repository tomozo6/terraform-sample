# ---------------------------------------------------------
# ECR
# ---------------------------------------------------------
resource "aws_ecr_repository" "api" {
  name                 = "api"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "sasaki" {
  name                 = "sasaki"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ---------------------------------------------------------
# ALB
# ---------------------------------------------------------
#tfsec:ignore:aws-elb-alb-not-public
resource "aws_lb" "api" {
  name                             = "${var.product}-${var.env}-api-alb"
  load_balancer_type               = "application"
  internal                         = false
  security_groups                  = [aws_security_group.api_alb.id]
  subnets                          = aws_subnet.public[*].id
  idle_timeout                     = 60
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = false
  enable_http2                     = true
  drop_invalid_header_fields       = true
  #  ip_address_type                  = "dualstack"

  access_logs {
    enabled = true
    bucket  = aws_s3_bucket.logs.bucket
    prefix  = "alb/${var.product}-${var.env}-api-alb"
  }

  tags = {
    Name = "${var.product}-${var.env}-api-alb"
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

# ---------------------------
# Security Group
# ---------------------------
resource "aws_security_group" "api_alb" {
  name   = "${var.product}-${var.env}-api-alb-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.product}-${var.env}-api-alb-sg"
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
#tfsec:ignore:aws-elb-alb-not-public:
# Target Group
# ---------------------------------------------------------
resource "aws_lb_target_group" "api" {
  name             = "${var.product}-${var.env}-api-tg"
  vpc_id           = aws_vpc.main.id
  port             = 50051
  protocol         = "HTTP"
  protocol_version = "GRPC"
  target_type      = "ip"

  #  deregistration_delay               = var.deregistration_delay
  #  slow_start                         = var.slow_start
  #  proxy_protocol_v2                  = var.proxy_protocol_v2
  #  lambda_multi_value_headers_enabled = var.lambda_multi_value_headers_enabled
  #  load_balancing_algorithm_type      = var.load_balancing_algorithm_type
  #  preserve_client_ip                 = var.preserve_client_ip

  health_check {
    enabled             = true
    port                = "traffic-port"
    path                = "/grpc.health.v1.Health/Check"
    matcher             = "0"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.product}-${var.env}-api-alb"
  }

  lifecycle {
    create_before_destroy = true
  }
}
# ---------------------------------------------------------
# ECS
# ---------------------------------------------------------
# IAM(execution)
resource "aws_iam_role" "api_ecs_task_execution" {
  name = "${var.product}-${var.env}-api-task-execution-role"

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

# IAM(task)
resource "aws_iam_role" "api_ecs_task" {
  name = "${var.product}-${var.env}-api-task-role"

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
  name = "${var.product}-${var.env}-api-task-policy"

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
        Sid    = "AllowKinesisPut"
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = [
          aws_kinesis_stream.drivingdata.arn
        ]
      },
      {
        Sid    = "AllowFirelensConfGet"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.firelensconf.arn,
          "${aws_s3_bucket.firelensconf.arn}/*",
        ]
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

# Security Group
resource "aws_security_group" "api_ecs" {
  name   = "${var.product}-${var.env}-api-ecs-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.product}-${var.env}-api-ecs-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "api_ecs_from_alb" {
  security_group_id            = aws_security_group.api_ecs.id
  referenced_security_group_id = aws_security_group.api_alb.id
  description                  = aws_security_group.api_alb.name
  ip_protocol                  = "tcp"
  from_port                    = 50051
  to_port                      = 50051
}

resource "aws_vpc_security_group_egress_rule" "api_ecs_to_all" {
  security_group_id = aws_security_group.api_ecs.id
  description       = "Allow to All"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
