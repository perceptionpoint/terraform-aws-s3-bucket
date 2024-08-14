resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name
  tags = var.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket-encryption-configuration" {
  bucket = aws_s3_bucket.bucket.bucket

  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
  count = var.encrypt_bucket? 1 : 0
}

resource "aws_s3_bucket_website_configuration" "bucket-website-configuration" {
  bucket = aws_s3_bucket.bucket.id

  index_document {
    suffix = var.bucket_website_configuration["index_document_suffix"]
  }

  error_document {
    key = var.bucket_website_configuration["error_document_key"]
  }

  count = (var.bucket_website_configuration != null)? 1 : 0
}

resource "aws_s3_bucket_ownership_controls" "bucket-ownership-controls" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    object_ownership = var.bucket_object_ownership_rule
  }
  count = (var.bucket_object_ownership_rule != null)? 1 : 0
}

resource "aws_s3_bucket_cors_configuration" "bucket-cors-configuration" {
  bucket = aws_s3_bucket.bucket.id

  dynamic cors_rule {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value["allowed_headers"]
      allowed_methods = cors_rule.value["allowed_methods"]
      allowed_origins = cors_rule.value["allowed_origins"]
      max_age_seconds = cors_rule.value["max_age_seconds"]
    }
  }

  count = (var.cors_rules != null)? 1 : 0
}

resource "aws_s3_bucket_policy" "bucket-policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = local.bucket_policy
  count = (local.bucket_policy != null)? 1 : 0
}

locals {
  publicly_readable_bucket_policy = <<POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "PublicReadForGetBucketObjects",
        "Effect": "Allow",
        "Principal": "*",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::${var.bucket_name}/*"
      }
    ]
  }
  POLICY
  bucket_policy = var.publicly_readable_to_anyone_in_the_internet? local.publicly_readable_bucket_policy : var.bucket_policy_document
}

resource "aws_s3_bucket_public_access_block" "bucket-public-access-block" {
  bucket = aws_s3_bucket.bucket.id

  # right now we only set all blocks to false, when the bucket is publicly readable
  # this is dangerouse to use this on s3 buckets, use when appropriate, and accept the risk
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  count = var.publicly_readable_to_anyone_in_the_internet? 1 : 0
}

resource "aws_s3_bucket_logging" "bucket-logging" {
  bucket = aws_s3_bucket.bucket.id

  target_bucket = var.bucket_logging["target_bucket"]
  target_prefix = var.bucket_logging["target_prefix"]

  count = (var.bucket_logging != null) ? 1 : 0
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket-lifecycle-configuration" {
  bucket = aws_s3_bucket.bucket.bucket
  count = (var.lifecycle_rules != null) ? 1 : 0

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value["expiration"] == null ? [] : [1]
        content {
          days_after_initiation = 1
        }
      }
      status = rule.value["enabled"]? "Enabled" : "Disabled"
      id = (rule.value["id"] == null)? rule.value["prefix"] : rule.value["id"]
      dynamic filter {
        for_each = (rule.value["prefix"] != null)? [1] : []
        content {
          prefix = "${rule.value["prefix"]}/"
        }
      }

      dynamic expiration {
        for_each = rule.value["expiration"] == null ? [] : [1]
        content {
          days = rule.value["expiration"]
          expired_object_delete_marker = false
        }
      }
         
      dynamic transition {
        for_each = rule.value["transition"] == null ? [] : [1]

        content {
          days = try(rule.value["transition"]["days"], null)
          storage_class = rule.value["transition"]["storage_class"] == null ? "STANDARD_IA" : rule.value["transition"]["storage_class"]
        }
      }

      dynamic noncurrent_version_expiration {
        for_each = rule.value["expiration"] == null ? [] : [1]
        content {
          noncurrent_days = rule.value["expiration"]
        }
      }

      dynamic noncurrent_version_transition {
        for_each = rule.value["transition"] == null ? [] : [1]

        content {
          noncurrent_days = try(rule.value["transition"]["days"], null)
          storage_class = rule.value["transition"]["storage_class"] == null ? "STANDARD_IA" : rule.value["transition"]["storage_class"]
        }
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_acl" "bucket-acl" {
  bucket = aws_s3_bucket.bucket.id
  access_control_policy {
    dynamic grant {
      for_each = var.access_control_policy["grants"]
      content {
        permission = grant.value["permission"]
        grantee {
          type = grant.value["type"]
          uri  = grant.value["uri"]
        }
      }
    }
    grant {
      permission = "FULL_CONTROL"
      grantee {
        id           = var.access_control_policy["owner"]
        type         = "CanonicalUser"
      }
    }
    owner {
      id = var.access_control_policy["owner"]
    }
  }

  count = (var.access_control_policy != null) ? 1 : 0
}
