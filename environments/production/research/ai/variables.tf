# ─────────────────────────────────────────────────────────────────────────────
# production/research/ai — GenAI agentic runtime
#
# Cross-layer values (KMS key, VPC, subnets, SG, IAM roles) are read from
# SSM Parameter Store — see data.tf.
#
# Creates SageMaker Studio (private AI dev environment) and will eventually
# include Bedrock endpoints and guardrails (deferred — see tasks.md).
#
# Pillar coverage:
#   1  Encryption:   KMS-encrypted EFS, EBS, FSx (SageMaker)
#   2  Access:       dedicated SageMaker execution role, least-privilege
#   3  Network:      VpcOnly SageMaker domain, no public access
#   4  HA:           multi-AZ by construction
#   5  Observability: CloudWatch alarms, execution logging
#   7  Residency:    data_classification + data_residency gates
#  10  FinOps:       default ml.t3.medium Studio instance, dev shutdown
# ─────────────────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment: dev, test, staging, prod, commercial"
  type        = string
  nullable    = false
  validation {
    condition     = contains(["dev", "test", "staging", "prod", "commercial"], var.environment)
    error_message = "Must be one of: dev, test, staging, prod, commercial."
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

variable "app_name" {
  description = "Short app name used in resource naming."
  type        = string
  nullable    = false
  default     = "app"
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
  description = "Cost management settings. Dev defaults to smallest Studio instance."
  type = object({
    cost_center            = optional(string, "engineering")
    project_code           = optional(string, "anestoa")
    studio_instance_type   = optional(string, "ml.t3.medium")
    shutdown_outside_hours = optional(bool, true)
  })
  nullable = true
  default  = null
}

variable "default_tags" {
  description = "Base tags merged into every resource."
  type        = map(string)
  nullable    = false
  default     = {}
}

# ── SageMaker-specific ─────────────────────────────────────────────────────────
variable "auth_mode" {
  description = "SageMaker Studio authentication: IAM or SSO."
  type        = string
  default     = "IAM"
  validation {
    condition     = contains(["IAM", "SSO"], var.auth_mode)
    error_message = "auth_mode must be IAM or SSO."
  }
}

variable "create_default_user" {
  description = "Create a default user profile."
  type        = bool
  default     = true
}

variable "default_user_name" {
  description = "Name for the default user profile."
  type        = string
  default     = "default-user"
}

variable "sagemaker_bucket_arns" {
  description = "S3 bucket ARNs for SageMaker data access."
  type        = list(string)
  default     = []
}
