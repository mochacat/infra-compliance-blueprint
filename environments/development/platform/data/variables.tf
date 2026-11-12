# ─────────────────────────────────────────────────────────────────────────────
# development/platform/data — Data layer (RDS pgvector + OpenSearch)
#
# Cross-layer values (KMS key ARN, VPC ID, subnets, SG, IAM role ARN) are
# read from SSM Parameter Store — never from terraform_remote_state or
# hardcoded. See data.tf for SSM data sources.
#
# Pillar coverage:
#   1  Encryption:   KMS CMK for RDS + OpenSearch at rest
#   3  Network:      private subnets, VPC endpoints
#   4  HA:           multi-AZ Aurora, OpenSearch standby replicas
#   5  Observability: CloudWatch alarms, centralized logging
#   6  Backup/DR:    retention ≥ 30, deletion protection, optional cross-region
#   7  Residency:    data_classification + data_residency gates
#  10  FinOps:       cost-center tags, dev-sized instances
# ─────────────────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment: dev, test, staging, prod, preprod, sandbox, commercial"
  type        = string
  nullable    = false
  validation {
    condition     = contains(["dev", "test", "staging", "prod", "preprod", "sandbox", "commercial"], var.environment)
    error_message = "Must be one of: dev, test, staging, prod, preprod, sandbox, commercial."
  }
}

variable "region" {
  description = "Target region. Must be in allowed_regions."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^(us-(east|west)-[12]|eu-(west|central)-[12])$", var.region))
    error_message = "Region is not an approved AWS region pattern."
  }
}

variable "allowed_regions" {
  description = "Approved regions."
  type        = list(string)
  nullable    = false
  default     = ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"]
}

# ── Pillar 6 — Backup, DR & Deletion Protection ──────────────────────────────
variable "backup" {
  description = "Backup and retention configuration."
  type = object({
    retention_days      = optional(number, 30)
    deletion_protection = optional(bool, true)
    skip_final_snapshot = optional(bool, false)
  })
  nullable = false
  default  = {}
}

# ── Pillar 5 — Observability ────────────────────────────────────────────────
variable "observability" {
  description = "Observability configuration."
  type = object({
    alarm_topic_arn    = optional(string, null)
    log_retention_days = optional(number, 90)
  })
  nullable = false
  default  = {}
}

# ── Pillar 7 — Data Residency & Sovereignty ───────────────────────────────────
# ── Business unit (for SSM path and naming) ──────────────────────────────────
variable "business_unit" {
  description = "Business unit for SSM path and resource naming: platform, research, data-platform."
  type        = string
  nullable    = false
  validation {
    condition     = contains(["platform", "research", "data-platform"], var.business_unit)
    error_message = "Must be one of: platform, research, data-platform."
  }
}
variable "data_classification" {
  description = "Data classification: internal, pii, phi, financial, cardholder"
  type        = string
  nullable    = false
  default     = "internal"
  validation {
    condition     = contains(["internal", "pii", "phi", "financial", "cardholder"], var.data_classification)
    error_message = "Must be one of: internal, pii, phi, financial, cardholder."
  }
}

variable "data_residency" {
  description = "Data residency constraints."
  type = object({
    sovereign_only                 = optional(bool, false)
    jurisdiction                   = optional(string, null)
    allow_cross_border_replication = optional(bool, false)
    cross_border_approval_ref      = optional(string, null)
  })
  nullable = false
  default  = {}
}

# ── Pillar 10 — FinOps & Cost Controls ────────────────────────────────────────
variable "cost_controls" {
  description = "Cost management settings. Dev defaults to smallest instances."
  type = object({
    cost_center  = optional(string, "engineering")
    project_code = optional(string, "anestoa")
  })
  nullable = false
  default  = {}
}

variable "default_tags" {
  description = "Base tags merged into every resource."
  type        = map(string)
  nullable    = false
  default     = {}
}

# ── App-specific ─────────────────────────────────────────────────────────────
variable "app_name" {
  description = "Short app name used in resource naming."
  type        = string
  nullable    = false
  default     = "app"
}

variable "master_username" {
  description = "Aurora master username."
  type        = string
  nullable    = false
  default     = "appuser"
}

# No secret_arn variable — the rds-pgvector module uses manage_master_user_password
# = true, so RDS auto-generates the password, stores it in Secrets Manager, and
# rotates it. The module outputs master_user_secret_arn for reference.
