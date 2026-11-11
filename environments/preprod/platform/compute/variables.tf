# ─────────────────────────────────────────────────────────────────────────────
# preprod/platform/compute — ECS cluster and compute resources
#
# Cross-layer values (KMS key, VPC, subnets, SG, IAM roles) are read from
# SSM Parameter Store — see data.tf.
#
# Pillar coverage:
#   1  Encryption:   KMS-encrypted task log groups
#   3  Network:      private Fargate tasks, no public IPs
#   4  HA:           multi-AZ task spread
#   5  Observability: Container Insights, CPU/memory alarms
#   7  Residency:    data_classification + data_residency gates
#  10  FinOps:       dev-sized instances, shutdown outside hours
# ─────────────────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment: dev, test, staging, prod, commercial"
  type        = string
  nullable    = false
  validation {
    condition     = contains(["dev", "test", "staging", "prod", "preprod", "commercial"], var.environment)
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
  description = "Cost management settings."
  type = object({
    cost_center            = optional(string, "engineering")
    project_code           = optional(string, "anestoa")
    shutdown_outside_hours = optional(bool, true)
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

# ── Compute-specific ─────────────────────────────────────────────────────────
variable "ecs_cluster_name" {
  description = "Name for the ECS cluster."
  type        = string
  nullable    = false
  default     = "main"
}
