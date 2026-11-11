# ─────────────────────────────────────────────────────────────────────────────
# IAM Role module — least-privilege IAM role for AI/regulated workloads.
#
# Pillar coverage:
#   2  Access:   scoped policy statements, permissions boundary, no wildcards
#   7  Residency: data_classification + data_residency tags and gates
#   9  Change:   environment validated, compliance_controls output
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

variable "name" {
  description = "Name of the IAM role."
  type        = string
  nullable    = false
}

variable "trust_policy" {
  description = <<-EOF
    JSON trust (assume-role) policy document. Controls who can assume this role.
    For service roles, use a Service principal. For cross-account access, use
    an AWS principal. The module does NOT validate the trust policy content —
    that is the caller's responsibility. However, wildcard principals are
    detected at OPA/SCP enforcement layers.

    Example (service):
    ```json
    {
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "ec2.amazonaws.com"},
        "Action": "sts:AssumeRole"
      }]
    }
    ```
  EOF
  type        = string
  nullable    = false
}

variable "policy_statements" {
  description = <<-EOF
    List of IAM policy statements for the role's inline policy. Each statement
    must have scoped Actions and Resources — wildcard Action or Resource is
    rejected at validation (Pillar 2: least privilege).

    Example:
    ```hcl
    policy_statements = [
      {
        sid       = "S3Access"
        effect    = "Allow"
        actions   = ["s3:GetObject", "s3:PutObject"]
        resources = ["arn:aws:s3:::my-bucket/*"]
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

  # Wildcard resource validation is handled by the check block in checks.tf
  # (can't reference allowed_resource_wildcards in a variable validation block).
}

variable "allowed_resource_wildcards" {
  description = "SIDs in policy_statements that are allowed to use wildcard Resource (*). Use sparingly — only for actions where the resource is scoped at a different layer (e.g. aoss:APIAccessAll scoped via collection access policy)."
  type        = list(string)
  default     = null
  nullable    = true
}

variable "permissions_boundary_arn" {
  description = "ARN of a permissions boundary policy. Required in prod (enforced via lifecycle precondition)."
  type        = string
  default     = null
}

variable "managed_policy_arns" {
  description = "List of managed policy ARNs to attach to the role. Use sparingly — prefer inline policy_statements."
  type        = list(string)
  nullable    = false
  default     = []
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