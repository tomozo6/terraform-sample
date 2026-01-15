resource "aws_ecs_cluster" "main" {
  name = "${var.product}-${var.env}-main-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.product}-${var.env}-main-ecs-cluster"
  }
}
