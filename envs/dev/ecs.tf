resource "aws_ecs_cluster" "main" {
  name = "${local.product}-${local.env}-main-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${local.product}-${local.env}-main-ecs-cluster"
  }
}




