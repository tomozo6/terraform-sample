# -------------------------------------------------------
# main
# -------------------------------------------------------
resource "aws_acm_certificate" "main" {
  domain_name               = local.product_fqdn
  subject_alternative_names = ["*.${local.product_fqdn}"]
  validation_method         = "DNS"
}

resource "aws_route53_record" "main_for_acm" {
  for_each = {
    for i in aws_acm_certificate.main.domain_validation_options : i.domain_name => {
      name   = i.resource_record_name
      record = i.resource_record_value
      type   = i.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.base.zone_id
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.main_for_acm : record.fqdn]
}

# us-east-1 (CloudFront用)
resource "aws_acm_certificate" "main_us_east_1" {
  provider                  = aws.us-east-1
  domain_name               = local.product_fqdn
  subject_alternative_names = ["*.${local.product_fqdn}"]
  validation_method         = "DNS"
}
