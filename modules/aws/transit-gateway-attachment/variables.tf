# ─────────────────────────────────────────────────────────────────────────────
# transit-gateway-attachment module — variables
#
# Follows the CLAUDE.md pillar conventions: nullable = false, validation blocks,
# standard interfaces for environment, data_classification, etc.
# ─────────────────────────────────────────────────────────────────────────────

# Pillar 9 — Change Management & Policy Enforcement (environment gating).
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
  description = "Human label for the attachment. Prefixes resource names and tags."
  type        = string
  nullable    = false
}

# ── Pillar 4 — High Availability & Region Control ───────────────────────────────────────────────
variable "allowed_regions" {
  description = "Approved regions for the TGW attachment. Rejected at plan time if outside this list."
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

# ── Core TGW attachment inputs ──────────────────────────────────────────────
variable "transit_gateway_id" {
  description = "The Network Hub's Transit Gateway ID (tgw-xxx)."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^tgw-", var.transit_gateway_id))
    error_message = "Must be a valid Transit Gateway ID starting with 'tgw-'."
  }
}

variable "vpc_id" {
  description = "The workload VPC ID (vpc-xxx)."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "Must be a valid VPC ID starting with 'vpc-'."
  }
}

variable "subnet_ids" {
  description = <<-EOF
    TGW-tier subnet IDs (≥ 2 AZs, max one per AZ). These are the workload VPC's
    TGW subnets, typically from the `vpc` module's subnet_ids output filtered
    to the "tgw" tier. At least 2 from different AZs required (Pillar 4 — High Availability & Region Control).
  EOF
  type        = list(string)
  nullable    = false
}

# ── Attachment options ───────────────────────────────────────────────────────
variable "dns_support" {
  description = "Enable DNS support on the attachment."
  type        = bool
  nullable    = false
  default     = true
}

variable "ipv6_support" {
  description = "Enable IPv6 support on the attachment."
  type        = bool
  nullable    = false
  default     = false
}

variable "appliance_mode_support" {
  description = <<-EOF
    TGW appliance mode. When "enable", the TGW routes traffic to/from this VPC
    through a firewall appliance (Network Firewall, NGFW) in the Network Hub for
    centralized network inspection. This is the single audit point for cross-VPC
    traffic required by HIPAA 164.312(a)(1) and SOC 2 CC6.7.
    Values: "enable" or "disable".
  EOF
  type        = string
  nullable    = false
  default     = "disable"
  validation {
    condition     = contains(["enable", "disable"], var.appliance_mode_support)
    error_message = "appliance_mode_support must be 'enable' or 'disable'."
  }
}

variable "auto_accept" {
  description = "Auto-accept the attachment request."
  type        = bool
  nullable    = false
  default     = true
}

variable "default_route_table_association" {
  description = <<-EOF
    Whether to associate this attachment with the TGW's default route table.
    Set to `false` when using a custom route table (e.g. for appliance-based
    centralized inspection).
  EOF
  type        = bool
  nullable    = false
  default     = true
}

variable "default_route_table_propagation" {
  description = <<-EOF
    Whether to propagate routes from this attachment into the TGW's default
    route table. Set to `false` for fine-grained route control.
  EOF
  type        = bool
  nullable    = false
  default     = true
}

variable "transit_gateway_route_table_id" {
  description = <<-EOF
    Specific TGW route table ID to associate this attachment with (e.g. the
    inspection route table that sends traffic through a firewall appliance).
    When set, overrides the default route table association and creates an
    explicit association resource. Set `default_route_table_association =
    "disable"` to avoid conflicts.
  EOF
  type        = string
  nullable    = true
  default     = null
}

variable "propagate_to_route_table_id" {
  description = <<-EOF
    TGW route table ID to propagate routes into (typically the hub's shared
    services route table). When set, the attachment's CIDR routes become
    reachable from that route table — enabling other spokes to route to this
    VPC without explicit static routes.
  EOF
  type        = string
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