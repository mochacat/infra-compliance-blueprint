# ─────────────────────────────────────────────────────────────────────────────
# CloudTrail module — infra-team-owned org audit trail.
#
# Pillar coverage:
#   1  Encryption: caller-provided CMK via kms_key_arn (never self-created)
#   5  Observability: CloudWatch streaming + default ingestion alarm
#   6  Backup:        versioning always on, Object Lock COMPLIANCE, 7-yr retention
#   7  Residency:     data_classification + data_residency gates on audit data
#   8  Auditability:  Object Lock COMPLIANCE, log-file validation, immutable log bucket
#   9  Change mgmt:   compliance_controls output for OPA/Atlantis
#  10  FinOps:        CostCenter / Project tags, no data events by default
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

variable "name" {
  description = "Trail name prefix. Becomes <name>-trail."
  type        = string
  nullable    = false
}

# ── Pillar 4 — Region Control ────────────────────────────────────────────────
# The trail's home region must be approved. The cross-variable check (region in
# allowed_regions) lives as a lifecycle precondition on the trail (OpenTofu
# forbids a variable validation from referencing another variable).
variable "allowed_regions" {
  description = "Approved regions. Rejected at plan time if the trail is outside this list."
  type        = list(string)
  nullable    = false
  default     = ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"]
}

variable "region" {
  description = "Home region for the trail. Must be in allowed_regions."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^(us-(east|west)-[12]|eu-(west|central)-[12])$", var.region))
    error_message = "Region is not an approved AWS region pattern."
  }
}

# ── Pillar 1 — Encryption at Rest & In Transit ───────────────────────────────
# The module encrypts the audit bucket and CloudWatch log group with a
# caller-provided CMK. It NEVER creates its own key and offers no off toggle.
variable "kms_key_arn" {
  description = "CMK ARN for encryption at rest (S3 bucket + CloudWatch log group). Module does NOT create a key."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "Must be a valid KMS key ARN."
  }
}

# ── Pillar 5 — Observability ─────────────────────────────────────────────────
variable "observability" {
  description = "CloudWatch streaming + alarm configuration."
  type = object({
    log_retention_days = optional(number, 90)
    alarm_topic_arn    = optional(string, null)
  })
  nullable = false
  default  = {}
}

# ── Pillar 6 — Backup / Retention (applied to CloudWatch logs) ───────────────
variable "backup" {
  description = "Log retention + deletion protection. The audit bucket itself always has Object Lock + versioning regardless of this."
  type = object({
    retention_days = optional(number, 90)
  })
  nullable = false
  default  = {}
  # Retention ≥ 30 enforced via lifecycle precondition (not a variable
  # validation) so expect_failures can attach to the trail resource.
}

# ── Pillar 7 — Data Residency & Sovereignty ──────────────────────────────────
variable "data_classification" {
  description = "Data classification: internal, pii, phi, financial, cardholder."
  type        = string
  nullable    = false
  default     = "internal"
  validation {
    condition     = contains(["internal", "pii", "phi", "financial", "cardholder"], var.data_classification)
    error_message = "Must be one of: internal, pii, phi, financial, cardholder."
  }
}

variable "data_residency" {
  description = "Data residency constraints on audit data."
  type = object({
    sovereign_only                   = optional(bool, false)
    jurisdiction                     = optional(string, null)
    allow_cross_border_replication   = optional(bool, false)
    cross_border_approval_ref        = optional(string, null)
    business_associate_agreement_req = optional(bool, false)
  })
  nullable = false
  default  = {}
}

# ── Pillar 8 — Auditability & Immutability ───────────────────────────────────
# The audit bucket always has Object Lock + versioning. Mode is COMPLIANCE by
# default; retention is a minimum 7 years (2557 days).
variable "audit_lock_mode" {
  description = "Object Lock mode: COMPLIANCE (default) or GOVERNANCE."
  type        = string
  default     = "COMPLIANCE"
  nullable    = false
  validation {
    condition     = contains(["COMPLIANCE", "GOVERNANCE"], var.audit_lock_mode)
    error_message = "Must be COMPLIANCE or GOVERNANCE."
  }
}

variable "audit_retention_days" {
  description = "Object Lock retention in days. Minimum 2557 (7 years)."
  type        = number
  default     = 2557
  nullable    = false
  # Minimum enforced via lifecycle precondition on the bucket so expect_failures
  # can attach to the bucket resource.
}

# ── Trail scope ──────────────────────────────────────────────────────────────
variable "is_organization_trail" {
  description = "Set true for an organization-wide trail (deployed in a delegated admin account)."
  type        = bool
  default     = true
  nullable    = false
}

variable "bucket_name_prefix" {
  description = "Prefix for the audit S3 bucket name. Defaults to var.name."
  type        = string
  default     = null
  nullable    = true
}

variable "data_events" {
  description = "Optional data event selectors. Empty = management events only (cheapest, Pillar 10-optimal)."
  type = object({
    s3     = optional(list(string), [])
    lambda = optional(list(string), [])
  })
  nullable = false
  default  = {}
}

variable "cloudtrail_insights" {
  description = "Optional CloudTrail Insights event selector."
  type = object({
    insights_type = optional(string, "ApiCallRateInsight")
  })
  nullable = true
  default  = null
}

# ── Pillar 2 — IAM (CloudTrail → CloudWatch role) ────────────────────────────
variable "iam" {
  description = "IAM role name prefix for the CloudTrail-to-CloudWatch role."
  type = object({
    cloudwatch_logs_role_name_prefix = optional(string, "")
  })
  nullable = false
  default  = {}
}

# ── Pillar 10 — FinOps ───────────────────────────────────────────────────────
variable "cost_controls" {
  description = "Cost management settings + mandatory cost tags."
  type = object({
    cost_center             = optional(string, null)
    project_code            = optional(string, null)
    budget_amount           = optional(number, null)
    budget_alert_thresholds = optional(list(number), [50, 80, 100])
    budget_email            = optional(string, null)
  })
  nullable = true
  default  = {}
}

variable "default_tags" {
  description = "Base tags merged into all resources."
  type        = map(string)
  nullable    = false
  default     = {}
}