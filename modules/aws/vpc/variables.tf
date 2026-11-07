# ─────────────────────────────────────────────────────────────────────────────
# VPC module — compliant-by-default VPC for AI/regulated workloads.
#
# Pillar coverage:
#   1  Encryption:   flow logs encrypted at rest via SSE-S3
#   3  Network:      private subnets only, CIDR overlap protection, default SG lockdown
#   4  HA:           multi-AZ subnets enforced (≥2 AZs)
#   5  Observability: VPC flow logs → centralized immutable audit bucket
#   7  Residency:    data_classification + data_residency tags and gates
#  10  FinOps:       CostCenter / Project tags
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
  description = "VPC name. Used as a prefix for subnet naming and tags."
  type        = string
  nullable    = false
}

variable "cidr_block" {
  description = "VPC CIDR block. Must be RFC-1918 private range, no 0.0.0.0/0, no host bits set."
  type        = string
  nullable    = false
  validation {
    condition = can(cidrhost(var.cidr_block, 0)) && (
      can(regex("^10\\.", cidrhost(var.cidr_block, 0))) ||
      can(regex("^172\\.(1[6-9]|2[0-9]|3[01])\\.", cidrhost(var.cidr_block, 0))) ||
      can(regex("^192\\.168\\.", cidrhost(var.cidr_block, 0)))
    ) && contains(range(16, 29), parseint(split("/", var.cidr_block)[1], 10))
    error_message = "CIDR must be a valid RFC-1918 private range with prefix /16-/28 (Pillar 3 — Network Security & Isolation)."
  }
}

variable "reserved_cidrs" {
  description = <<-EOF
    Existing CIDR blocks that the proposed VPC must NOT overlap. In a hub-and-spoke
    topology, pass (at minimum) the hub VPC's CIDR here plus any peer/spoke CIDRs
    that are already deployed. The module rejects overlap at plan time via a lifecycle
    precondition (Pillar 3 — Network Security & Isolation / SCP-aligned CIDR management).
    Example: ["10.0.0.0/16", "10.1.0.0/16"]
  EOF
  type        = list(string)
  nullable    = false
  default     = []
}

# Pillar 4 — High Availability & Region Control.
variable "allowed_regions" {
  description = "Approved regions for VPC placement. Rejected at plan time if outside this list."
  type        = list(string)
  nullable    = false
  default     = ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"]
}

variable "region" {
  description = "Target region for the VPC. Must be in allowed_regions."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^(us-(east|west)-[12]|eu-(west|central)-[12])$", var.region))
    error_message = "Region is not an approved AWS region pattern."
  }
}

# Subnets — multi-AZ private subnets per tier.
variable "subnets" {
  description = <<-EOF
    Subnet configuration. Each key is a tier name (e.g. "app", "data", "tgw").
    For each tier, provide the AZs and a CIDR per AZ in matching order.

    Example:
    ```hcl
    subnets = {
      app = {
        availability_zones = ["us-east-1a", "us-east-1b"]
        cidrs              = ["10.0.1.0/24", "10.0.2.0/24"]
      }
      data = {
        availability_zones = ["us-east-1a", "us-east-1b"]
        cidrs              = ["10.0.3.0/24", "10.0.4.0/24"]
      }
    }
    ```
  EOF
  type = map(object({
    availability_zones = list(string)
    cidrs              = list(string)
  }))
  nullable = false
  default  = {}
}

# Pillar 5 — Observability (VPC flow logs to the centralized immutable audit bucket)
variable "flow_log_destination" {
  description = <<-EOF
    Destination for VPC Flow Logs. Must be an Alexa S3 bucket ARN in the Log Archive
    account (cross-account). The bucket must have an appropriate bucket policy that
    grants s3:PutObject from this VPC's account.

    The `bucket_arn` is the immutable audit bucket (see landing-zone/baseline/audit-bucket.tf).
    The `bucket_owner_account_id` is the owning account ID of that bucket, used to set up
    cross-account S3 delivery privileges. Both are required: `bucket_arn` is the log
    destination; `bucket_owner_account_id` satisfies the cross-account ownership check
    that the VPC Flow Logs service requires under the hood.
  EOF
  type = object({
    bucket_arn              = string
    bucket_owner_account_id = optional(string, null) # inferred from caller if not cross-account
  })
  nullable = true
  default  = null
}

# Pillars 7 + 10 — data classification, residency, cost.
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
