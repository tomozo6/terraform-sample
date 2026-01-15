# -----------------------------------------------------------------------
# S3
# -----------------------------------------------------------------------
resource "aws_s3_bucket" "logs" {
  bucket        = "${var.product}-${var.env}-logs-s3"
  force_destroy = false

  tags = {
    Name = "${var.product}-${var.env}-logs-s3"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.product}-${var.env}-logs-s3/cloudtrail/AWSLogs/${local.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AllowALBWrite"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.current.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/*"
      },
      #      {
      #        Sid    = "AllowCloudFrontWrite"
      #        Effect = "Allow"
      #        Principal = {
      #          Service = "delivery.logs.amazonaws.com"
      #        }
      #        Action   = "s3:PutObject"
      #        Resource = "${aws_s3_bucket.logs.arn}/*"
      #        Condition = {
      #          StringEquals = {
      #            "s3:x-amz-acl"      = "bucket-owner-full-control"
      #            "aws:SourceAccount" = var.account_id
      #          },
      #          ArnLike = {
      #            "aws:SourceArn" : "arn:aws:logs:us-east-1:${var.account_id}:delivery-source:*"
      #          }
      #        }
      #      },
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# CloudFrontのログ保管のために必要な設定
resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# ACLを設定
resource "aws_s3_bucket_acl" "logs" {
  depends_on = [aws_s3_bucket_ownership_controls.logs]
  bucket     = aws_s3_bucket.logs.id
  acl        = "private"
}
