variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment tag."
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Target region (must be in allowed_regions — Pillar 4)."
}

variable "allowed_regions" {
  type        = list(string)
  default     = ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"]
  description = "Approved regions for bucket placement."
}

variable "kms_key_arn" {
  type        = string
  description = "CMK ARN used to encrypt the app data bucket (Pillar 1 — Encryption)."
}

variable "audit_kms_key_arn" {
  type        = string
  description = "CMK ARN used to encrypt the audit bucket (Pillar 8 — Auditability & Immutability)."
}

variable "audit_log_bucket_id" {
  type        = string
  default     = null
  description = "Name/id of the centralized access-log bucket (Pillar 5 — Observability). Null to disable logging."
}

variable "data_classification" {
  type        = string
  default     = "internal"
  description = "Data classification: internal, pii, phi, financial, cardholder."
}

variable "data_residency" {
  type = object({
    sovereign_only = optional(bool, false)
    jurisdiction   = optional(string, null)
  })
  default     = {}
  description = "Data residency constraints."
}

variable "jurisdiction" {
  type        = string
  default     = "us"
  description = "Sovereign jurisdiction tag."
}

variable "cost_center" {
  type        = string
  default     = "platform"
  description = "Cost allocation tag."
}

variable "project_code" {
  type        = string
  default     = "anestoa"
  description = "Project cost tag."
}