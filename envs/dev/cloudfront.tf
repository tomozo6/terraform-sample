# ---------------------------------------------------------
# IP
# ---------------------------------------------------------
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# ---------------------------------------------------------
# OAC
# ---------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${local.product}-${local.env}-cf-oac"
  description                       = ""
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ---------------------------------------------------------
# Route53
# ---------------------------------------------------------
resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.base.zone_id
  name    = local.product_fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

# ---------------------------------------------------------
# Distribution
# ---------------------------------------------------------
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  aliases             = [local.product_fqdn]
  is_ipv6_enabled     = false
  comment             = ""
  default_root_object = "index.html"
  price_class         = "PriceClass_200"
  http_version        = "http2"
  web_acl_id          = aws_wafv2_web_acl.main.arn
  wait_for_deployment = false

  #  logging_config {
  #    include_cookies = false
  #    bucket          = aws_s3_bucket.logs.bucket_domain_name
  #    prefix          = "cf/${local.main_domain_name}"
  #  }
  #  

  origin {
    domain_name              = aws_s3_bucket.web.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.web.bucket
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  origin {
    domain_name = aws_lb.api.dns_name
    origin_id   = aws_lb.api.name

    custom_origin_config {
      http_port                = "80"
      https_port               = "443"
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_keepalive_timeout = 5
      origin_read_timeout      = 30
    }
  }

  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.web.bucket
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  }

  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = aws_lb.api.name
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Host"]

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = aws_acm_certificate.main_us_east_1.arn
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  depends_on = [
    aws_s3_bucket_public_access_block.web,
    aws_s3_bucket_ownership_controls.web
  ]
}
