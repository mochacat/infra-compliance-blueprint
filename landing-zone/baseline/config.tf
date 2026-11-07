# ─────────────────────────────────────────────────────────────────────────────
# Organization AWS Config
#
# Recorders configuration, security, and compliance state changes for every
# account in the org. Results snapshot to a centralized bucket and stream to
# a per-account/aggregated delivery channel so drift is visible.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_config_configuration_recorder" "org" {
  # Config's delivery channel needs the audit bucket, so it is gated on the
  # log archive account as well as the config_org toggle.
  count = (var.config_org && var.log_archive_account_id != null) ? 1 : 0

  name     = "org-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "org" {
  count = (var.config_org && var.log_archive_account_id != null) ? 1 : 0

  name           = "org-config-channel"
  s3_bucket_name = aws_s3_bucket.audit[0].id
  sns_topic_arn  = aws_sns_topic.config[0].arn

  snapshot_delivery_properties {
    delivery_frequency = "Six_Hours"
  }
}

resource "aws_config_configuration_recorder_status" "org" {
  count = (var.config_org && var.log_archive_account_id != null) ? 1 : 0

  name       = aws_config_configuration_recorder.org[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.org]
}

resource "aws_iam_role" "config" {
  count = (var.config_org && var.log_archive_account_id != null) ? 1 : 0

  name               = "ConfigOrgRole"
  assume_role_policy = data.aws_iam_policy_document.config_assume[0].json
  description        = "Allows AWS Config to record resource changes."
  tags               = var.default_tags
}

data "aws_iam_policy_document" "config_assume" {
  count = (var.config_org && var.log_archive_account_id != null) ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "config_permissions" {
  count = (var.config_org && var.log_archive_account_id != null) ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.audit_log_bucket}/config/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_iam_role_policy" "config" {
  count = (var.config_org && var.log_archive_account_id != null) ? 1 : 0

  role   = aws_iam_role.config[0].name
  policy = data.aws_iam_policy_document.config_permissions[0].json
}

resource "aws_sns_topic" "config" {
  count = (var.config_org && var.log_archive_account_id != null) ? 1 : 0

  name = "config-notifications"
  tags = merge(var.default_tags, { Name = "config-notifications" })
}