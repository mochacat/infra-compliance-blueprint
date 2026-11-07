# ─────────────────────────────────────────────────────────────────────────────
# opensearch-collection module — OpenSearch Serverless vector store
#
# Pillar coverage:
#   1  Encryption:   caller-provided KMS CMK via an encryption security policy
#   3  Network:      ALWAYS a private AOSS VPC endpoint + private network policy
#   4  HA:           standby_replicas = ENABLED by default (multi-AZ)
#   5  Observability: CloudTrail data-plane audit + default health alarm (SNS)
#   6  Backup/DR:    data lifecycle (retention) policy ≥ 30 days
#   7  Residency:    data_classification + data_residency gates
#  10  FinOps:       cost tags, budget wiring when budget set
# ─────────────────────────────────────────────────────────────────────────────

# ── VPC endpoint (always provisioned — Pillar 3) ─────────────────────────────
# OpenSearch Serverless uses its OWN VPC endpoint type (distinct from the
# aws_vpc_endpoint interface endpoints in the vpc-endpoint module). It is the
# private data-plane path into the collection and is always created.
resource "aws_opensearchserverless_vpc_endpoint" "this" {
  name               = "${var.name}-aoss-vpce"
  vpc_id             = var.network.vpc_id
  subnet_ids         = var.network.subnet_ids
  security_group_ids = var.network.security_group_ids
  # Note: the AOSS vpc_endpoint resource does not expose a tags attribute;
  # attribution tags live on the collection and policy resources.

  lifecycle {
    # Subnet-count gate (Pillar 4) — enforced here (not a variable validation)
    # so expect_failures can attach to the resource. HA requires ≥ 2 AZs.
    precondition {
      condition     = length(var.network.subnet_ids) >= 2
      error_message = "VPC endpoint requires at least 2 subnets in different AZs (Pillar 4 — High Availability & Region Control)."
    }
    precondition {
      condition     = length(var.network.security_group_ids) >= 1
      error_message = "At least one security group is required for the VPC endpoint (Pillar 3 — Network Security & Isolation)."
    }
  }
}

# ── Encryption policy (Pillar 1) ─────────────────────────────────────────────
# Binds this collection name to the caller's CMK. Encryption at rest is required
# by AOSS and defaults to a CMK here — never an AWS-owned key.
resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "${var.name}-encryption"
  type        = "encryption"
  policy      = local.encryption_policy_json
  description = "CMK encryption for ${local.collection_name}"
}

# ── Network policy (Pillar 3) — ALWAYS private ───────────────────────────────
# AllowFromPublic = false, source is only the module's own VPC endpoint.
# There is no public-access path through this module.
resource "aws_opensearchserverless_security_policy" "network" {
  name        = "${var.name}-network"
  type        = "network"
  policy      = local.network_policy_json
  description = "Private network access for ${local.collection_name}"
}

# ── Data access policy (Pillar 2) ────────────────────────────────────────────
# Grants read/write ONLY to the caller's principals. No wildcard principals.
resource "aws_opensearchserverless_access_policy" "data" {
  name        = "${var.name}-data"
  type        = "data"
  policy      = local.access_policy_json
  description = "Least-privilege data access for ${local.collection_name}"
}

# ── Data lifecycle policy (Pillar 6) ─────────────────────────────────────────
# AOSS has no native deletion-protection toggle; index retention is enforced
# with a lifecycle policy. Documents/automatic snapshots are service-managed.
resource "aws_opensearchserverless_lifecycle_policy" "data" {
  name        = "${var.name}-retention"
  type        = "retention"
  policy      = local.lifecycle_policy_json
  description = "Index retention for ${local.collection_name}"
}

# ── The collection ───────────────────────────────────────────────────────────
resource "aws_opensearchserverless_collection" "this" {
  # checkov:skip=CKV_AWS_158:KMS encryption is applied via the matching encryption security policy (local.encryption_policy_json), the AWS-recommended mechanism for AOSS. Checkov cannot statically resolve policy-to-collection binding on name pattern.
  name             = local.collection_name
  type             = var.collection.type
  description      = local.collection_description
  standby_replicas = var.high_availability.standby_replicas
  tags             = local.base_tags

  # The collection must be created AFTER the encryption + network policies that
  # match its name are in place, so the CMK and private access attach on create.
  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.data,
    aws_opensearchserverless_lifecycle_policy.data,
  ]

  lifecycle {
    # Region gate (Pillar 4)
    precondition {
      condition     = contains(var.allowed_regions, var.region)
      error_message = "Region ${var.region} is not in approved allowed_regions (Pillar 4 — High Availability & Region Control)."
    }
    # Residency gate (Pillar 7) — PHI requires sovereign_only
    precondition {
      condition     = var.data_residency.sovereign_only == true || var.data_classification != "phi"
      error_message = "PHI requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty)."
    }
    # Retention gate (Pillar 6) — enforced here (not a variable validation)
    # so expect_failures can attach to the resource.
    precondition {
      condition     = var.backup.retention_days >= 30
      error_message = "Minimum retention is 30 days (Pillar 6 — Backup, DR & Deletion Protection)."
    }
  }
}

# ── Pillar 5 — default health alarm (optional) ───────────────────────────────
# AOSS emits collection health/capacity+2xx/4xx/5xx metrics to CloudWatch. When
# an SNS topic is provided, wire a default alarm so the collection never runs
# in the dark.
resource "aws_cloudwatch_metric_alarm" "collection_4xx" {
  count = var.observability.alarm_topic_arn != null ? 1 : 0

  alarm_name          = "${var.name}-aoss-4xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xx"
  namespace           = "AWS/AOSS"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "OpenSearch Serverless ${local.collection_name} returned 4xx errors"
  alarm_actions       = [var.observability.alarm_topic_arn]
  tags                = local.base_tags
}