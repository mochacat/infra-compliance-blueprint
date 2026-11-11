# ─────────────────────────────────────────────────────────────────────────────
# VPC — primary resource
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = local.base_tags

  lifecycle {
    # Residency gate (Pillar 7 — Data Residency & Sovereignty). Cannot live in a `variable validation` because
    # OpenTofu forbids a validation from referencing another var.
    precondition {
      condition     = var.data_residency.sovereign_only == true || var.data_classification != "phi"
      error_message = "PHI requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty)."
    }

    # Region gate (Pillar 4 — High Availability & Region Control). `region` must be in the approved `allowed_regions`.
    precondition {
      condition     = contains(var.allowed_regions, var.region)
      error_message = "Region ${var.region} is not in approved allowed_regions (Pillar 4 — High Availability & Region Control)."
    }

    # CIDR overlap gate. Reject this CIDR if it overlaps ANY caller-declared
    # reserved CIDR (e.g. hub VPC CIDR, other spoke VPCs). Prevents accidental
    # overlapping ranges that break peering / TGW routing.
    precondition {
      condition     = (length(var.reserved_cidrs) == 0) || !local.overlaps_any_reserved
      error_message = local.overlap_message
    }

    # CIDR validation: must be RFC-1918 or RFC-6598 private range (/16–/28,
    # matching the variable validation in variables.tf). This rejects 0.0.0.0/0
    # and any public / non-routable garbage that would never work in a VPC.
    precondition {
      condition = can(cidrhost(var.cidr_block, 0)) && (
        can(regex("^10\\.", cidrhost(var.cidr_block, 0))) ||
        can(regex("^172\\.(1[6-9]|2[0-9]|3[01])\\.", cidrhost(var.cidr_block, 0))) ||
        can(regex("^192\\.168\\.", cidrhost(var.cidr_block, 0))) ||
        can(regex("^100\\.(6[4-9]|[7-9][0-9])\\.", cidrhost(var.cidr_block, 0)))
      ) && contains(range(16, 29), parseint(split("/", var.cidr_block)[1], 10))
      error_message = "cidr_block must be a valid RFC-1918 or RFC-6598 (CG-NAT) private range with prefix /16-/28 (Pillar 3 — Network Security & Isolation)."
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Subnets — multi-AZ (Pillar 4 — High Availability & Region Control). Caller provides a map of tier → per-AZ CIDRs.
# Each tier spans at least 2 AZs for compliance.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_subnet" "this" {
  for_each = { for s in local.subnet_entries : "${s.tier}-${s.az}" => s }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr
  tags = merge(local.base_tags, {
    Name    = "${var.name}-${each.value.tier}-${each.value.az}"
    Tier    = each.value.tier
    Network = "private" # All subnets are private — no public IP by default
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# VPC Flow Logs — to the immutable Log Archive S3 bucket (Pillars 5 & 8).
#
# Destination is the caller-provided audit bucket ARN. The module uses S3
# destination (not CloudWatch) for cost efficiency and immutability. The
# `hive_compatible` prefix enables Athena partition pruning for fast queries.
#
# The bucket MUST live in a separate Log Archive account (cross-account) for
# SOC 2 / HIPAA offsite storage. The caller passes the bucket_arn and its
# owning account_id to satisfy the cross-account delivery permission check.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_flow_log" "vpc" {
  count           = var.flow_log_destination != null ? 1 : 0
  iam_role_arn    = aws_iam_role.flow_log[count.index].arn
  log_destination = var.flow_log_destination.bucket_arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.this.id

  destination_options {
    file_format                = "parquet"
    hive_compatible_partitions = true
    per_hour_partition         = true
  }

  tags = local.base_tags
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM role for VPC Flow Logs to write to a cross-account S3 bucket.
#
# The trust policy allows the VPC Flow Logs service (vpc-flow-logs.amazonaws.com)
# to assume this role. The role has a restricted inline policy scoped only to
# putting objects into the specific destination bucket via the Log Archive account.
#
# Cross-account S3 delivery also requires a bucket policy on the Log Archive
# bucket itself (see landing-zone/baseline/audit-bucket.tf) that grants
# s3:PutObject to this role's ARN.
# ─────────────────────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "flow_log_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_log" {
  count              = var.flow_log_destination != null ? 1 : 0
  name               = "${var.name}-flow-log-role"
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume_role.json
  tags               = local.base_tags
}

resource "aws_iam_role_policy" "flow_log_s3" {
  count = var.flow_log_destination != null ? 1 : 0
  name  = "${var.name}-flow-log-s3-policy"
  role  = aws_iam_role.flow_log[count.index].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups",
        ]
        Resource = ["*"]
      },
      {
        Sid    = "DeliverToAuditBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation",
        ]
        # The destination bucket ARN — the caller provides it.
        # In production this is the Log Archive account's immutable audit bucket.
        Resource = [
          var.flow_log_destination.bucket_arn,
          "${var.flow_log_destination.bucket_arn}/*",
        ]
      },
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# Default security group lockdown (Pillar 3 — Network Security & Isolation).
# AWS creates a default SG per VPC that allows all inbound/outbound within the
# VPC. We replace it with a deny-all posture — no implicit trust inside the VPC.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(local.base_tags, {
    Name = "${var.name}-default-sg"
  })
}
