# ─────────────────────────────────────────────────────────────────────────────
# deploy-role module — variables
#
# Cross-account role that CI/CD (Atlantis) assumes in each account to run
# plans and applies. Intentionally NOT AdministratorAccess — it is scoped to
# what automation needs, with a permissions boundary that cannot be widened.
#
# Pillar coverage:
#   2  Access:   scoped policy, permissions boundary, no admin access
#   7  Residency: data_classification + data_residency gates
#   9  Change:   environment validated, compliance_controls output
#  10  FinOps:   CostCenter / Project tags
# ─────────────────────────────────────────────────────────────────────────────

variable "role_name" {
  description = "Name of the deploy role."
  type        = string
  nullable    = false
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN the role trusts."
  type        = string
  nullable    = false
}

variable "allowed_subjects" {
  description = "OIDC subjects allowed to assume the role (repo:org/repo:ref:main)."
  type        = list(string)
  default     = ["repo:*:*:ref:refs/heads/main"]
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary applied to the role. Required in prod (enforced via lifecycle precondition)."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags applied to the role. Merged with pillar tags from locals."
  type        = map(string)
  default     = {}
}

# ── Pillar 9 — Change Management & Policy Enforcement ───────────────────────

variable "environment" {
  description = "Environment: dev, test, staging, prod, preprod, sandbox, commercial"
  type        = string
  nullable    = false
  validation {
    condition     = contains(["dev", "test", "staging", "prod", "preprod", "sandbox", "commercial"], var.environment)
    error_message = "Must be one of: dev, test, staging, prod, preprod, sandbox, commercial (Pillar 9 — Change Management & Policy Enforcement)."
  }
}

# ── Pillar 7 — Data Residency & Sovereignty ─────────────────────────────────

variable "data_classification" {
  description = "Data classification: internal, pii, phi, financial, cardholder"
  type        = string
  nullable    = false
  default     = "internal"
  validation {
    condition     = contains(["internal", "pii", "phi", "financial", "cardholder"], var.data_classification)
    error_message = "Must be one of: internal, pii, phi, financial, cardholder (Pillar 7 — Data Residency & Sovereignty)."
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

# ── Pillar 10 — FinOps & Cost Controls ──────────────────────────────────────

variable "cost_controls" {
  description = "Cost allocation tags."
  type = object({
    cost_center  = optional(string, null)
    project_code = optional(string, null)
  })
  nullable = false
  default  = { cost_center = null, project_code = null }
}