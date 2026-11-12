# ─────────────────────────────────────────────────────────────────────────────
# production/data-platform/iam — IAM roles for this account
#
# Creates the application-level IAM roles that compute, data, and AI layers
# consume. Each downstream layer reads role ARNs via SSM Parameter Store
# (see CLAUDE.md § Cross-Layer Communication).
#
# The control plane (deploy-role) is managed by landing-zone/baseline/.
# This layer creates only app roles.
#
# Pillar coverage:
#   2  Access:   dedicated roles per resource, scoped policies, permissions boundary
#   7  Residency: data_classification + data_residency gates
#   9  Change:   environment gating, compliance_controls output for OPA
#  10  FinOps:   CostCenter / Project tags
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

variable "allowed_regions" {
  description = "Approved regions. Rejected at plan time if outside this list."
  type        = list(string)
  nullable    = false
  default     = ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"]
}

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

# ── Pillar 7 — Data Residency & Sovereignty ───────────────────────────────────
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

# ── Pillar 1 — Encryption (KMS for downstream layers) ─────────────────────────
# This layer creates a KMS key that other layers in this account can use for
# encryption at rest. In production, you'd pass a centrally-managed key ARN
# instead — this is a dev convenience.
variable "kms_key_arn" {
  description = "CMK ARN for encryption at rest. If null, this layer creates a key for dev use."
  type        = string
  nullable    = true
  default     = null
  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "Must be a valid KMS key ARN or null."
  }
}

# ── Pillar 2 — IAM permissions boundary ───────────────────────────────────────
variable "permissions_boundary_arn" {
  description = "ARN of a permissions boundary policy for all roles. Required in prod."
  type        = string
  default     = null
}

# ── Pillar 10 — FinOps & Cost Controls ────────────────────────────────────────
variable "cost_controls" {
  description = "Cost management settings."
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

# ── App naming ────────────────────────────────────────────────────────────────
# ── Pillar 4 — Account ID (for least-privilege policy ARNs) ──────────────
# The account id is required to build scoped IAM policy ARNs
# (arn:aws:iam::<account>:role/...). Supplied by the caller; CI provides a
# dummy value so plans generate offline without an STS call.
variable "account_id" {
  description = "AWS account ID used to scope IAM policy ARNs."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "app_name" {
  description = "Short app name used in role names, e.g. 'rag-api'. Customize per workload."
  type        = string
  nullable    = false
  default     = "app"
}
