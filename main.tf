provider "aws" {
  region = "us-east-1"
}

locals {
  buckets = toset([
    "edp-dev-delta-lake-bronze",
    "edp-dev-delta-lake-silver",
    "edp-dev-delta-lake-gold",
  ])
}

# One KMS key shared by all buckets
resource "aws_kms_key" "s3" {
  description             = "S3 object encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

# Buckets
resource "aws_s3_bucket" "this" {
  for_each = local.buckets
  bucket   = each.key
}

# Ownership controls
resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

# Private ACL (depends on ownership controls as required by AWS)
resource "aws_s3_bucket_acl" "this" {
  for_each   = aws_s3_bucket.this
  depends_on = [aws_s3_bucket_ownership_controls.this]
  bucket     = each.value.id
  acl        = "private"
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "this" {
  for_each                  = aws_s3_bucket.this
  bucket                    = each.value.id
  block_public_acls         = true
  block_public_policy       = true
  ignore_public_acls        = true
  restrict_public_buckets   = true
}

# Versioning
resource "aws_s3_bucket_versioning" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  versioning_configuration { status = "Enabled" }
}

# SSE-KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}
