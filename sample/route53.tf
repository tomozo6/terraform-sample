resource "aws_route53_zone" "roadsync" {
  name = var.main_domain_name
}
