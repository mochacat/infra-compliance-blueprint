# ─────────────────────────────────────────────────────────────────────────────
# vpc-endpoint module — variables
#
# Follows the CLAUDE.md pillar conventions: nullable = false, validation blocks,
# standard interfaces for environment, data_classification, etc.
# ─────────────────────────────────────────────────────────────────────────────

# Pillar 9 — Change Management & Policy Enforcement (environment gating).
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
  description = "Human label for the endpoints. Prefixes resource names and tags."
  type        = string
  nullable    = false
}

# ── Pillar 4 — High Availability & Region Control ───────────────────────────────────────────────
variable "allowed_regions" {
  description = "Approved regions for VPC endpoints. Rejected at plan time if outside this list."
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

variable "vpc_id" {
  description = "The VPC to create endpoints in (vpc-xxx)."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "Must be a valid VPC ID starting with 'vpc-'."
  }
}

# ── Gateway endpoints (S3, DynamoDB) ────────────────────────────────────────
variable "gateway_endpoints" {
  description = <<-EOF
    Gateway VPC endpoints to create. Each entry:
    - service: e.g. "s3" or "dynamodb" (Gateway endpoints support these two)
    - route_table_ids: the route tables to add the prefix-list route to.
    Gateway endpoints are free and require no security group.

    Example:
    ```hcl
    gateway_endpoints = [
      { service = "s3", route_table_ids = ["rtb-xxx", "rtb-yyy"] },
      { service = "dynamodb", route_table_ids = ["rtb-xxx", "rtb-yyy"] },
    ]
    ```
  EOF
  type = list(object({
    service         = string
    route_table_ids = list(string)
  }))
  nullable = false
  default  = []
}

# ── Interface endpoints (SSM, STS, CloudWatch, KMS, etc.) ───────────────────
variable "interface_endpoints" {
  description = <<-EOF
    Interface VPC endpoints to create. Each entry:
    - service: e.g. "ssm", "sts", "monitoring", "kms", "ecr.api", "logs"
    - subnet_ids: ≥ 2 subnets in different AZs (Pillar 4 — High Availability & Region Control)
    - private_dns_enabled: resolve the service's public DNS to the endpoint (default true)

    Example:
    ```hcl
    interface_endpoints = [
      { service = "ssm", subnet_ids = ["subnet-xxx", "subnet-yyy"] },
      { service = "sts", subnet_ids = ["subnet-xxx", "subnet-yyy"] },
      { service = "kms", subnet_ids = ["subnet-xxx", "subnet-yyy"] },
    ]
    ```
  EOF
  type = list(object({
    service             = string
    subnet_ids          = list(string)
    private_dns_enabled = optional(bool, true)
  }))
  nullable = false
  default  = []
}

# ── Security group for interface endpoints ──────────────────────────────────
# Interface endpoints require a security group. The caller provides it — it
# should be scoped to allow only the traffic the endpoint needs (least
# privilege, Pillar 2). Reusing the VPC's default (locked-down) SG is common.
variable "security_group_ids" {
  description = <<-EOF
    Security group IDs attached to interface VPC endpoints. Should be scoped
    to allow only the specific service traffic the endpoint carries (least
    privilege — Pillar 2). The caller owns the SG so it can be shared across
    all endpoints.
  EOF
  type        = list(string)
  nullable    = false
  default     = []
}

# ── Endpoint policy (optional, least privilege) ─────────────────────────────
# A single IAM-style policy applied to all endpoints. When null, AWS applies
# the default (full access) policy for each endpoint. For least privilege,
# provide a policy that restricts actions/principals.
variable "endpoint_policy" {
  description = <<-EOF
    A single IAM policy document applied to all VPC endpoints in this module.
    When null, AWS applies each endpoint's default (permissive) policy. For
    least privilege (Pillar 2 — Access Control & Least Privilege), pass a policy that restricts actions and
    principals to what the VPC actually needs. For example, restrict S3
    Gateway endpoint access to a specific bucket.

    Pass a decoded JSON object (use jsondecode(data.aws_iam_policy_document.x.json)
    or a literal map). The module re-encodes it.
  EOF
  type        = any
  nullable    = true
  default     = null
}

# ── Pillar 7 — Data Residency & Sovereignty ──────────────────────────────
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

# ── Pillar 10 — FinOps & Cost Controls ──────────────────────────────────────────────────────
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
  description = "Base tags merged onto every resource."
  type        = map(string)
  default     = {}
}