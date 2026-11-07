# ─────────────────────────────────────────────────────────────────────────────
# S3 Bucket module — compliant-by-default S3 bucket.
#
# Pillar coverage:
#   1  Encryption: caller-provided CMK via kms_key_arn (no SSE-S3, no off toggle)
#   2  Access:     TLS-only access, no public ACLs, private by default
#   3  Network:    private-only, public access blocked at every layer
#   6  Backup:     versioning on, optional Object Lock, deletion protection
#   7  Residency:  data_classification + data_residency tags and gates
#   8  Audit:      Object Lock COMPLIANCE for audit buckets, 7-year retention
#  10  FinOps:     CostCenter / Project tags
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

# Pillar 4 — High Availability & Region Control. Only approved regions are deployable; the bucket's
# target region must be in `allowed_regions`. The non-self-referential check (region
# in allowed_regions) lives as a `lifecycle precondition` on the bucket resource —
# OpenTofu forbids a `variable validation` from referencing another variable.
variable "allowed_regions" {
  description = "Approved regions for bucket placement. Rejected at plan time if outside this list."
  type        = list(string)
  nullable    = false
  default     = ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"]
}

variable "region" {
  description = "Target region for the bucket. Must be in allowed_regions."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^(us-(east|west)-[12]|eu-(west|central)-[12])$", var.region))
    error_message = "Region is not an approved AWS region pattern."
  }
}

variable "name" {
  description = "Bucket name. Must be globally unique."
  type        = string
  nullable    = false
}

# Pillar 1 — encryption at rest. Caller MUST provide a CMK.
variable "kms_key_arn" {
  description = "CMK ARN for encryption at rest. Module does NOT create a key."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "Must be a valid KMS key ARN."
  }
}

variable "audit_bucket" {
  description = "True if this bucket stores audit/immutability evidence (enables Object Lock)."
  type        = bool
  default     = false
}

variable "audit_lock_mode" {
  description = "Object Lock mode: COMPLIANCE or GOVERNANCE."
  type        = string
  default     = "COMPLIANCE"
  validation {
    condition     = contains(["COMPLIANCE", "GOVERNANCE"], var.audit_lock_mode)
    error_message = "Must be COMPLIANCE or GOVERNANCE."
  }
}

variable "audit_retention_days" {
  description = "Audit log retention in days. Minimum 2557 (7 years)."
  type        = number
  default     = 2557
  validation {
    condition     = var.audit_retention_days >= 2557
    error_message = "Minimum audit retention is 2557 days (7 years)."
  }
}

variable "versioning_enabled" {
  description = "Enable S3 versioning."
  type        = bool
  default     = true
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

# Pillar 5 — Observability (centralized destination for access logs).
variable "observability" {
  description = "Centralized logging destination."
  type = object({
    log_bucket_id   = optional(string, null) # S3 access logs → this bucket (name/id, not ARN)
    log_prefix      = optional(string, "s3-logs/")
    alarm_topic_arn = optional(string, null) # Future: bucket-level alarms
  })
  nullable = false
  default  = {}
}

variable "cost_controls" {
  description = "FinOps tags."
  type = object({
    cost_center  = optional(string, null)
    project_code = optional(string, null)
  })
  nullable = false
  default  = { cost_center = null, project_code = null }
}

variable "default_tags" {
  description = "Base tags applied to all resources."
  type        = map(string)
  default     = {}
}