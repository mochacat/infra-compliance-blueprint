# ─────────────────────────────────────────────────────────────────────────────
# Cross-Account Role module — trust policy gated to specific source accounts.
#
# Pillar coverage:
#   2  Access:   trust pinned to explicit source accounts, permissions
#                boundary, no wildcard resources in delegation policy
#   7  Residency: data_classification + data_residency tags and gates
#   9  Change:   environment validated, compliance_controls output
#  10  FinOps:   CostCenter / Project tags
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
  description = "Name of the cross-account role."
  type        = string
  nullable    = false
}

variable "source_account_arns" {
  description = <<-EOF
    List of AWS account IDs or role ARNs allowed to assume this role.
    Each must be a valid ARN or account ID. Wildcard accounts are rejected.

    Examples:
      source_account_arns = ["arn:aws:iam::111111111111:root"]
      source_account_arns = ["arn:aws:iam::111111111111:role/SecurityAudit"]
  EOF
  type        = list(string)
  nullable    = false

  validation {
    condition = alltrue([
      for arn in var.source_account_arns :
      can(regex("^arn:aws:iam::[0-9]{12}:", arn))
    ])
    error_message = "Each source account must be a valid IAM ARN (arn:aws:iam::<12-digit>:...)."
  }
}

variable "trust_conditions" {
  description = <<-EOF
    Optional conditions for the trust policy. Use to require ExternalId, MFA,
    or specific session tags.

    Example (ExternalId):
    ```hcl
    trust_conditions = {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = ["my-external-id"]
    }
    ```
  EOF
  type = object({
    test     = optional(string, null)
    variable = optional(string, null)
    values   = optional(list(string), null)
  })
  nullable = true
  default  = null
}

variable "policy_statements" {
  description = <<-EOF
    List of IAM policy statements scoping what the assumed role can do.
    Wildcard Action or Resource is rejected (Pillar 2 — Access Control & Least Privilege).

    Example:
    ```hcl
    policy_statements = [
      {
        sid       = "ReadS3"
        effect    = "Allow"
        actions   = ["s3:GetObject"]
        resources = ["arn:aws:s3:::shared-bucket/*"]
      }
    ]
    ```
  EOF
  type = list(object({
    sid       = optional(string, "")
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  nullable = false
  default  = []

  validation {
    condition = alltrue([
      for st in var.policy_statements :
      !contains(st.actions, "*")
    ])
    error_message = "Wildcard Action (*) is forbidden in policy_statements (Pillar 2 — Access Control & Least Privilege)."
  }

  validation {
    condition = alltrue([
      for st in var.policy_statements :
      !contains(st.resources, "*")
    ])
    error_message = "Wildcard Resource (*) is forbidden in policy_statements (Pillar 2 — Access Control & Least Privilege)."
  }
}

variable "permissions_boundary_arn" {
  description = "ARN of a permissions boundary policy. Required in prod (enforced via lifecycle precondition)."
  type        = string
  default     = null
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds (3600–43200)."
  type        = number
  default     = 3600
  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "Session duration must be between 3600 and 43200 seconds."
  }
}

variable "path" {
  description = "Path for the IAM role."
  type        = string
  default     = "/"
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

variable "cost_controls" {
  description = "Cost allocation tags."
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