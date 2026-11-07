# ─────────────────────────────────────────────────────────────────────────────
# Organization CloudTrail
#
# Agent of record for all API activity across every account. Multi-region,
# log file validation enabled, streams read-only + write events to the audit
# bucket in the Log Archive account. The DenyCloudTrailDisable SCP prevents
# anyone (including account admins) from stopping or modifying this trail.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudtrail" "org" {
  count = (var.cloudtrail_org && var.log_archive_account_id != null) ? 1 : 0

  name                          = local.org_trail_name
  s3_bucket_name                = aws_s3_bucket.audit[0].id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  is_organization_trail         = true
  kms_key_id                    = aws_kms_key.audit[0].arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.org_trail[0].arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch[0].arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }

    data_resource {
      type = "AWS::Lambda::Function"
      values = [
        "arn:aws:lambda",
      ]
    }
  }

  tags = merge(var.default_tags, { Name = local.org_trail_name })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "org_trail" {
  count = (var.cloudtrail_org && var.log_archive_account_id != null) ? 1 : 0

  name              = "/aws/cloudtrail/${local.org_trail_name}"
  retention_in_days = var.cloudwatch_log_retention
  tags              = merge(var.default_tags, { Name = "cloudtrail-logs" })
}

resource "aws_iam_role" "cloudtrail_cloudwatch" {
  count = (var.cloudtrail_org && var.log_archive_account_id != null) ? 1 : 0

  name               = "CloudTrail_CloudWatchLogs_Role"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume[0].json
  tags               = var.default_tags
}

data "aws_iam_policy_document" "cloudtrail_assume" {
  count = (var.cloudtrail_org && var.log_archive_account_id != null) ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cloudtrail_cw_put" {
  count = (var.cloudtrail_org && var.log_archive_account_id != null) ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.org_trail[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "cloudtrail_cw_put" {
  count = (var.cloudtrail_org && var.log_archive_account_id != null) ? 1 : 0

  role   = aws_iam_role.cloudtrail_cloudwatch[0].name
  policy = data.aws_iam_policy_document.cloudtrail_cw_put[0].json
}