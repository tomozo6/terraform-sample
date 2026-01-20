# ---------------------------------------------------------
# IP Set
# ---------------------------------------------------------
resource "aws_wafv2_ip_set" "office" {
  provider           = aws.us-east-1
  name               = "office"
  description        = "office"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = local.office_addresses
}

# ---------------------------------------------------------
# ACL
# ---------------------------------------------------------
resource "aws_wafv2_web_acl" "main" {
  provider    = aws.us-east-1
  name        = "${local.product}-${local.env}-main-waf-acl"
  description = "${local.product}-${local.env}-main-waf-acl"
  scope       = "CLOUDFRONT"

  default_action {
    block {}
  }

  # 可視性設定: CloudWatchメトリクスとログ
  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "AllowOnlySpecificIPsACL"
    sampled_requests_enabled   = true
  }

  # ルール: 許可されたIPSetからのリクエストのみを許可
  rule {
    name     = "AllowFromSpecificIPSet"
    priority = 1
    action {
      allow {}
    }

    statement {
      # IPSetを参照するステートメント
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.office.arn
      }
    }

    # ルール単位の可視性設定
    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "AllowFromSpecificIPSetRule"
      sampled_requests_enabled   = true
    }
  }
}
