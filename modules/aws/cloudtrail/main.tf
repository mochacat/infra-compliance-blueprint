# ─────────────────────────────────────────────────────────────────────────────
# cloudtrail module — infra-team-owned, org-wide audit trail.
#
# Pillar coverage:
#   1  Encryption: caller-provided CMK (S3 bucket + CloudWatch log group)
#   3  Network:    public access blocked at every layer; TLS-only
#   5  Observability: CloudWatch streaming + alarm_topic for trail ingestion
#   6  Backup:        bucket versioning on; prevent_destroy on the trail
#   7  Residency:     PHI-sovereign gate on audit data
#   8  Audit:         Object Lock COMPLIANCE, 7-yr retention, log-file validation
#  10  FinOps:        cost tags
# ─────────────────────────────────────────────────────────────────────────────

# ── Audit S3 bucket (Pillar 8) ───────────────────────────────────────────────
# Object Lock is enabled AT CREATION (required by AWS) and never disabled.
# force_destroy is false — audit logs can never be wiped by a normal destroy.
resource "aws_s3_bucket" "audit" {
  bucket              = local.bucket_name
  object_lock_enabled = true
  force_destroy       = false
  tags                = local.base_tags
  # checkov:skip=CKV2_AWS_62:Audit bucket must not have arbitrary event notifications; CloudTrail delivery is enforced via the bucket policy and CloudWatch stream (Pillar 8).
  # checkov:skip=CKV_AWS_18:Server access logging destination is not provided by this single-bucket module; the same object lifecycle is captured by CloudTrail data events (Pillar 5).
  # checkov:skip=CKV2_AWS_61:A lifecycle policy would delete or transition audit objects, violating the 7-year COMPLIANCE Object Lock retention (Pillar 8).
  # checkov:skip=CKV_AWS_144:Cross-region replication of the audit bucket is an explicit opt-in handled by the caller, not forced on the compliance source-of-truth bucket (Pillar 4/6).

  lifecycle {
    # Short Object Lock retention would allow early deletion (Pillar 8).
    precondition {
      condition     = var.audit_retention_days >= 2557
      error_message = "Minimum Object Lock retention is 2557 days (7 years) — Pillar 8 (Auditability & Immutability)."
    }
    # Short log retention against the bucket's stated retention (Pillar 6).
    precondition {
      condition     = var.observability.log_retention_days >= 30
      error_message = "Minimum log retention is 30 days — Pillar 6 (Backup, DR & Deletion Protection)."
    }
  }
}

# ── Versioning — always on (Pillar 6/8: immutable, restorable) ───────────────
resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ── Object Lock configuration (Pillar 8) ─────────────────────────────────────
resource "aws_s3_bucket_object_lock_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id

  rule {
    default_retention {
      mode = local.lock_mode
      days = var.audit_retention_days
    }
  }
}

# ── Encryption at rest — caller-provided CMK (Pillar 1) ──────────────────────
resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = local.kms_key_id
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# ── Public access blocked at every layer (Pillar 3) ──────────────────────────
resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Bucket policy: SecureTransport-only; allow CloudTrail delivery ───────────
# Denies all non-TLS transport; allows only CloudTrail to write. The bucket is
# private by topology (no public endpoints) and TLS-only by policy.
resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

data "aws_iam_policy_document" "bucket_policy" {
  # Pillar 1 (Transport): reject any request not over TLS.
  statement {
    sid    = "DenyNonSecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.audit.arn, "${aws_s3_bucket.audit.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Allow CloudTrail to deliver logs into the bucket.
  statement {
    sid    = "AllowCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.audit.arn}/AWSLogs/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

# ── CloudWatch log group for trail streaming (Pillar 5) ──────────────────────
resource "aws_cloudwatch_log_group" "trail" {
  name              = local.log_group_name
  retention_in_days = var.observability.log_retention_days
  kms_key_id        = local.kms_key_id
  tags              = local.base_tags
}

# ── CloudTrail → CloudWatch IAM role (Pillar 2 least-privilege) ──────────────
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume.json
  tags               = local.base_tags

  # Pillar 2: no wildcard resource; pattern-scoped to our trail's log group.
  inline_policy {
    name = "CloudTrailCloudWatchLogs"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["logs:PutLogEvents", "logs:CreateLogStream"]
          Resource = "${aws_cloudwatch_log_group.trail.arn}:*"
        }
      ]
    })
  }
}

data "aws_iam_policy_document" "cloudtrail_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

# ── The trail itself (Pillar 5/8) ────────────────────────────────────────────
resource "aws_cloudtrail" "this" {
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.audit.id
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  include_global_service_events = true
  is_organization_trail         = var.is_organization_trail
  kms_key_id                    = local.kms_key_id
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch.arn
  # checkov:skip=CKV_AWS_252:Trail notifications are routed via the CloudWatch stream + ingestion alarm rather than an SNS topic; the module exposes alarm_topic_arn via aws_cloudwatch_metric_alarm (Pillar 5).

  dynamic "event_selector" {
    for_each = (
      length(var.data_events.s3) > 0 || length(var.data_events.lambda) > 0
    ) ? [1] : []
    content {
      read_write_type           = "All"
      include_management_events = true

      dynamic "data_resource" {
        for_each = length(var.data_events.s3) > 0 ? [var.data_events.s3] : []
        content {
          type   = "AWS::S3::Object"
          values = data_resource.value
        }
      }

      dynamic "data_resource" {
        for_each = length(var.data_events.lambda) > 0 ? [var.data_events.lambda] : []
        content {
          type   = "AWS::Lambda::Function"
          values = data_resource.value
        }
      }
    }
  }

  dynamic "insight_selector" {
    for_each = var.cloudtrail_insights != null ? [1] : []
    content {
      insight_type = var.cloudtrail_insights.insights_type
    }
  }

  tags = merge(local.base_tags, { Name = local.trail_name })

  depends_on = [
    aws_s3_bucket_policy.audit,
  ]

  lifecycle {
    # Audit trail must never be silently deleted (Pillar 6/8). Static literal —
    # lifecycle meta-arguments cannot reference variables.
    prevent_destroy = true

    # Region gate (Pillar 4).
    precondition {
      condition     = contains(var.allowed_regions, var.region)
      error_message = "Region ${var.region} is not in allowed_regions — Pillar 4 (High Availability & Region Control)."
    }
    # Residency gate (Pillar 7) — audit data may carry PHI.
    precondition {
      condition     = var.data_residency.sovereign_only == true || var.data_classification != "phi"
      error_message = "PHI requires sovereign_only = true — Pillar 7 (Data Residency & Sovereignty)."
    }
  }
}

# ── Pillar 5 — default ingestion alarm (optional) ────────────────────────────
# If a topic is provided, alarm when the trail stops ingesting (no events for
# 1 hour), so a broken audit trail never runs in the dark.
resource "aws_cloudwatch_metric_alarm" "trail_stopped" {
  count = var.observability.alarm_topic_arn != null ? 1 : 0

  alarm_name          = "${local.trail_name}-ingestion-stopped"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TrailEventCount"
  namespace           = "AWS/CloudTrail"
  period              = "3600"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "CloudTrail ${local.trail_name} stopped ingesting events"
  alarm_actions       = [var.observability.alarm_topic_arn]
  tags                = local.base_tags
}