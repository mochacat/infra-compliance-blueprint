# ─────────────────────────────────────────────────────────────────────────────
# network-hub / transit-gateway terraservice — variables
#
# Infra-team OWNED control-plane layer. Every workload `network/` terraservice
# attaches to this Transit Gateway and reads its ID from SSM.
#
# SSM contract:
#   name  = /infrastructure/network-hub/transit-gateway/id
#   value = the aws_ec2_transit_gateway id
#
# Column: security posture is invariant (enforced by preconditions); only cost
# sizing varies per environment — see create-workload skill.
# ─────────────────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment: dev, test, staging, prod, preprod, sandbox, commercial"
  type        = string
  nullable    = false
  validation {
    condition     = contains(["dev", "test", "staging", "prod", "preprod", "sandbox", "commercial"], var.environment)
    error_message = "Must be one of: dev, test, staging, prod, preprod, sandbox, commercial (Pillar 9 — Change Management & Policy Enforcement)."
  }
}

variable "name" {
  description = "Hub Transit Gateway name. Default derives a stable hub name."
  type        = string
  nullable    = false
  default     = "network-hub"
}

variable "region" {
  description = "Target region. Must be in allowed_regions (Pillar 4 — High Availability & Region Control)."
  type        = string
  nullable    = false
}

variable "allowed_regions" {
  description = "Approved regions. Rejected at plan time if outside this list (Pillar 4)."
  type        = list(string)
  nullable    = false
  default     = ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"]
}

# ── Pillar 7 — Data Residency & Sovereignty ───────────────────────────────────
# The hub carries metadata about all attached workloads' networks; declare the
# highest classification it must contain so gates fire appropriately.
variable "data_classification" {
  description = "Data classification: internal, pii, phi, financial, cardholder."
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
    sovereign_only                   = optional(bool, false)
    jurisdiction                     = optional(string, null)
    allow_cross_border_replication   = optional(bool, false)
    cross_border_approval_ref        = optional(string, null)
    business_associate_agreement_req = optional(bool, false)
  })
  nullable = false
  default  = {}
  # NOTE: the PHI-sovereign gate (classification "phi" → sovereign_only = true)
  # lives on the aws_ec2_transit_gateway lifecycle precondition (main.tf) because
  # a variable validation can only reference the variable itself.
}

# ── Pillar 1 — Encryption at Rest ─────────────────────────────────────────────
# The SSM parameter is encrypted at rest with a caller-provided CMK. The module
# does NOT create its own key.
variable "kms_key_arn" {
  description = "CMK ARN for encrypting the published SSM parameter at rest. Module does NOT create a key."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "Must be a valid KMS key ARN (Pillar 1 — Encryption: At Rest and In Transit)."
  }
}

# ── Pillar 10 — FinOps & Cost Controls ────────────────────────────────────────
variable "cost_controls" {
  description = "Cost management settings (tags the hub resources for allocation)."
  type = object({
    cost_center  = optional(string, null)
    project_code = optional(string, null)
    budget_email = optional(string, null)
  })
  nullable = true
  default  = {}
}

variable "default_tags" {
  description = "Base tags merged into every resource (CostCenter, Environment, Project)."
  type        = map(string)
  nullable    = false
  default     = {}
}

# ── Transit Gateway specifics ─────────────────────────────────────────────────
variable "auto_accept_shared_attachments" {
  description = "Automatically accept attachment requests from accounts that share the TG."
  type        = string
  nullable    = false
  default     = "disable"
  validation {
    condition     = contains(["disable", "enable"], var.auto_accept_shared_attachments)
    error_message = "Must be 'disable' or 'enable'."
  }
}

variable "default_route_table_association" {
  description = "Whether the TG auto-associates attachments to the default route table."
  type        = string
  nullable    = false
  default     = "enable"
  validation {
    condition     = contains(["disable", "enable"], var.default_route_table_association)
    error_message = "Must be 'disable' or 'enable'."
  }
}

variable "default_route_table_propagation" {
  description = "Whether the TG auto-propagates attachments to the default route table."
  type        = string
  nullable    = false
  default     = "enable"
  validation {
    condition     = contains(["disable", "enable"], var.default_route_table_propagation)
    error_message = "Must be 'disable' or 'enable'."
  }
}

# ── Cross-account TG discovery (Pillar 3 Network / Pillar 2 Least Privilege) ─
# For a Transit Gateway spanning accounts, discovery is via RAM — NOT an SSM param
# (an SSM param lives in one account and cannot be read cross-account). The hub
# shares the TG; each workload account accepts the share and looks the shared TG
# up in its OWN account via data.aws_ec2_transit_gateway (same id both sides).
variable "participants" {
  description = "AWS account IDs (org principals) to share the Transit Gateway with. Least-privilege: no wildcard — every workload account that should attach is named explicitly (Pillar 2 — Access Control & Least Privilege)."
  type        = list(string)
  nullable    = false
  default     = []
  validation {
    condition     = alltrue([for p in var.participants : can(regex("^\\d{12}$", p))])
    error_message = "Each participant must be a 12-digit AWS account ID (Pillar 2 — Access Control & Least Privilege)."
  }
}