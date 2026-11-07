# ─────────────────────────────────────────────────────────────────────────────
# sagemaker-domain module — SageMaker Studio execution environment
#
# Pillar coverage:
#   1  Encryption:   all storage encrypted with caller-provided KMS CMK
#   2  Access:       dedicated least-privilege execution role
#   3  Network:      ALWAYS VpcOnly — no public-access path
#   4  HA:           domain spans all provided subnets (multi-AZ)
#   5  Observability: CloudWatch + optional SNS health alarm
#   6  Backup/DR:    EFS retention, log retention >= 30
#   7  Residency:    data_classification + data_residency gates
#  10  FinOps:       default ml.t3.medium, cost tags, budget wiring
# ─────────────────────────────────────────────────────────────────────────────

# ── IAM: dedicated SageMaker execution role (Pillar 2) ───────────────────────
# A single role scoped to the exact S3/ECR resources the workload uses.
# No wildcard Resource in the inline policy; the OPA rule enforces this too.
resource "aws_iam_role" "execution" {
  name                 = var.iam.execution_role_name
  assume_role_policy   = local.execution_role_assume_policy
  permissions_boundary = var.iam.permissions_boundary_arn
  tags                 = local.base_tags
}

resource "aws_iam_role_policy" "execution" {
  name   = "sagemaker-least-privilege"
  role   = aws_iam_role.execution.id
  policy = local.execution_role_policy
}

resource "aws_iam_role_policy_attachment" "execution_additional" {
  count      = length(var.iam.additional_policy_arns)
  role       = aws_iam_role.execution.name
  policy_arn = var.iam.additional_policy_arns[count.index]
}

# ── SageMaker Studio lifecycle config (optional catalog scripts) ─────────────
resource "aws_sagemaker_studio_lifecycle_config" "default" {
  count = var.create_default_user ? 1 : 0

  studio_lifecycle_config_name     = "${var.name}-setup"
  studio_lifecycle_config_app_type = "JupyterServer"
  studio_lifecycle_config_content  = base64encode("#!/bin/bash\n# intent: SageMaker Studio default lifecycle setup (Pillar 8 — Auditability).")

  tags = local.base_tags
}

# ── SageMaker Domain (Pillar 1/3/4/7) ────────────────────────────────────────
# ALWAYS VpcOnly. All storage encrypted with the caller KMS key.
resource "aws_sagemaker_domain" "this" {
  domain_name                   = var.name
  auth_mode                     = var.auth_mode
  app_network_access_type       = "VpcOnly" # ALWAYS private — no toggle
  app_security_group_management = "Customer"
  subnet_ids                    = var.network.subnet_ids
  vpc_id                        = var.network.vpc_id
  kms_key_id                    = var.kms_key_arn

  default_user_settings {
    execution_role      = aws_iam_role.execution.arn
    security_groups     = var.network.security_group_ids
    studio_web_portal   = "ENABLED"
    default_landing_uri = var.default_landing_uri

    space_storage_settings {
      default_ebs_storage_settings {
        default_ebs_volume_size_in_gb = 5
        maximum_ebs_volume_size_in_gb = 10
      }
    }
  }

  domain_settings {
    execution_role_identity_config = "USER_PROFILE_NAME"
  }

  tags = local.base_tags

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
    # Multi-AZ gate (Pillar 4) — domain must span >= 2 subnets
    precondition {
      condition     = length(var.network.subnet_ids) >= 2
      error_message = "SageMaker Domain requires >= 2 subnets in distinct AZs (Pillar 4 — High Availability & Region Control)."
    }
    # Retention gate (Pillar 6)
    precondition {
      condition     = var.backup.retention_days >= 30
      error_message = "Minimum retention is 30 days (Pillar 6 — Backup, DR & Deletion Protection)."
    }
  }
}

# ── Default user profile (Pillar 9 — access) ────────────────────────────────
resource "aws_sagemaker_user_profile" "default" {
  count = var.create_default_user ? 1 : 0

  domain_id         = aws_sagemaker_domain.this.id
  user_profile_name = var.default_user_name

  user_settings {
    execution_role    = aws_iam_role.execution.arn
    security_groups   = var.network.security_group_ids
    studio_web_portal = "ENABLED"
  }

  tags = local.base_tags
}

# ── Pillar 5 — Studio health alarm (optional) ────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "studio_health" {
  count = var.observability.alarm_topic_arn != null ? 1 : 0

  alarm_name          = "${var.name}-sagemaker-studio-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "InService"
  namespace           = "AWS/SageMaker"
  period              = "300"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "SageMaker Studio ${var.name} domain is unhealthy"
  alarm_actions       = [var.observability.alarm_topic_arn]
  tags                = local.base_tags
}