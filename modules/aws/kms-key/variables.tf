# ─────────────────────────────────────────────────────────────────────────────
# KMS Key module — customer-managed key (CMK) for encryption at rest.
#
# Encryption: every stateful resource must use a caller-provided
# CMK. THIS module is the producer of those keys. Because a key that is
# mis-configured undermines every resource that uses it, the defaults are
# strict and several controls are NOT configurable:
#
#   - Rotation is ALWAYS on (no toggle — a disabled-rotation key is rejected)
#   - Deletion window is enforced >= 30 days (deletion protection analog)
#   - Key policy grants are scoped to explicit principals — no "*" principals
#   - Cross-region (multi_region) is gated: PHI keys may not be multi-region
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

variable "kms" {
  description = "KMS key configuration."
  type = object({
    alias_prefix         = optional(string, "")   # Prefix for the key alias, e.g. "app-"
    description          = optional(string, null) # Purpose of the key
    key_spec             = optional(string, "SYMMETRIC_DEFAULT")
    usage                = optional(string, "ENCRYPT_DECRYPT")
    deletion_window_days = optional(number, 30) # >= 30 enforced
    multi_region         = optional(bool, false)
    iam_principals       = list(string) # Explicit principals allowed to use the key
    admins               = list(string) # Principals that can administer the key
  })
  nullable = false

  validation {
    condition     = var.kms.deletion_window_days >= 30
    error_message = "Deletion window must be at least 30 days (Pillar 6 — Backup, DR & Deletion Protection)."
  }
  validation {
    condition     = length(var.kms.iam_principals) > 0
    error_message = "At least one IAM principal must be allowed to use the key (no wildcard/empty grants)."
  }
}

# data_classification determines residency gates (Pillar 7 — Data Residency & Sovereignty).
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
    sovereign_only                   = optional(bool, false)
    jurisdiction                     = optional(string, null)
    allow_cross_border_replication   = optional(bool, false)
    cross_border_approval_ref        = optional(string, null)
    business_associate_agreement_req = optional(bool, false)
  })
  nullable = false
  default  = { sovereign_only = false }
}

variable "cost_controls" {
  description = "Cost allocation tags."
  type = object({
    cost_center  = optional(string, null)
    project_code = optional(string, null)
  })
  nullable = false
  default  = { cost_center = null, project_code = null }
}

variable "allowed_regions" {
  description = "Approved regions."
  type        = list(string)
  nullable    = false
  default     = ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"]
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

variable "account_id" {
  description = "AWS account ID that owns this key. Used to scope the root-principal grant in the key policy. Explicit, not derived at runtime, so plans validate offline."
  type        = string
  nullable    = false
}

variable "default_tags" {
  description = "Base tags applied to all resources."
  type        = map(string)
  default     = {}
}