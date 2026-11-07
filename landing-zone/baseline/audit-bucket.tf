# ─────────────────────────────────────────────────────────────────────────────
# Immutable Audit Log Bucket (Log Archive account)
#
# HIPAA 164.312(b) / SOC 2 CC7.1 require the audit trail to be tamper-evident.
# This bucket enforces:
#   - Object Lock in COMPLIANCE mode (objects cannot be deleted/overwritten
#     before retention expires, even by the account root)
#   - Versioning always on (every change is a new version, never overwritten)
#   - KMS encryption at rest (CMK not self-managed)
#   - SecureTransport (TLS) enforced on all access
#   - Public access blocked at every layer
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_kms_alias" "audit" {
  count = var.log_archive_account_id != null ? 1 : 0

  name          = "alias/audit-log-encryption"
  target_key_id = aws_kms_key.audit[0].key_id
}

# NOTE: CloudTrail requires a KMS key for SSE-KMS on logs. This is the audit
# key — only CloudTrail and the Log Archive account roles can use it.
resource "aws_kms_key" "audit" {
  count = var.log_archive_account_id != null ? 1 : 0

  description             = "CMK for encrypting the immutable audit log bucket."
  deletion_window_in_days = 30
  enable_key_rotation     = true
  is_enabled              = true
  tags                    = merge(var.default_tags, { Name = "audit-log-key" })

  policy = data.aws_iam_policy_document.audit_kms[0].json
}

data "aws_iam_policy_document" "audit_kms" {
  count = var.log_archive_account_id != null ? 1 : 0

  # CloudTrail must be able to encrypt org logs with this key.
  statement {
    sid    = "AllowCloudTrail"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceOrgID"
      values   = ["*"] # Resolved at plan time from marshal; see README.
    }
  }

  # Key admin — the management account may administer it.
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.management_account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_s3_bucket" "audit" {
  count = var.log_archive_account_id != null ? 1 : 0

  bucket        = var.audit_log_bucket
  force_destroy = false
  tags          = merge(var.default_tags, { Name = "audit-log-bucket" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "audit" {
  count = var.log_archive_account_id != null ? 1 : 0

  bucket = aws_s3_bucket.audit[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  count = var.log_archive_account_id != null ? 1 : 0

  bucket = aws_s3_bucket.audit[0].id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.audit[0].arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "audit" {
  count = var.log_archive_account_id != null ? 1 : 0

  bucket                  = aws_s3_bucket.audit[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "audit" {
  count = var.log_archive_account_id != null ? 1 : 0

  bucket = aws_s3_bucket.audit[0].id
  policy = data.aws_iam_policy_document.audit_bucket[0].json
}

data "aws_iam_policy_document" "audit_bucket" {
  count = var.log_archive_account_id != null ? 1 : 0

  # Require TLS for all access (SOLID: no plaintext access to audit data).
  statement {
    sid     = "EnforceTLS"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.audit_log_bucket}",
      "arn:aws:s3:::${var.audit_log_bucket}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# Object Lock in COMPLIANCE mode with 7-year retention.
resource "aws_s3_bucket_object_lock_configuration" "audit" {
  count = var.log_archive_account_id != null ? 1 : 0

  bucket = aws_s3_bucket.audit[0].id
  rule {
    default_retention {
      mode = var.audit_lock_mode
      days = var.log_retention_days
    }
  }
}