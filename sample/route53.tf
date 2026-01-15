data "aws_route53_zone" "base" {
  name = local.base_fqdn
}
