# ---------------------------------------------------------
# S3
# ---------------------------------------------------------
resource "aws_s3_bucket" "athena" {
  bucket        = "${var.product}-${var.env}-athena-s3"
  force_destroy = false

  tags = {
    Name = "${var.product}-${var.env}-athena-s3"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena" {
  bucket = aws_s3_bucket.athena.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "athena" {
  bucket                  = aws_s3_bucket.athena.bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "athena" {
  bucket = aws_s3_bucket.athena.id

  versioning_configuration {
    status = "Enabled"
  }
}
