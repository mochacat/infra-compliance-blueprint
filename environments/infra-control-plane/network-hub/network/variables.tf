# ─────────────────────────────────────────────────────────────────────────────
# network-hub / network terraservice — variables
#
# Infra-team OWNED control-plane layer. Creates the hub VPC, attaches to the
# shared Transit Gateway, and deploys shared VPC endpoints for the hub account.
# ─────────────────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment: dev, test, staging, prod, commercial."
  type        = string
  nullable    = false
  validation {
    condition     = contains(["dev", "test", "staging", "prod", "commercial"], var.environment)
    error_message = "Must be one of: dev, test, staging, prod, commercial (Pillar 9 — Change Management & Policy Enforcement)."
  }
}

variable "name" {
  description = "Human label for the hub network. Defaults to 'network-hub'."
  type        = string
  nullable    = false
  default     = "network-hub"
}

# ── Pillar 4 — High Availability & Region Control ───────────────────────────
variable "allowed_regions" {
  description = "Approved regions. Rejected at plan time if outside this list."
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
    error_message = "Region is not an approved AWS region pattern (Pillar 4 — High Availability & Region Control)."
  }
}

# ── Pillar 7 — Data Residency & Sovereignty ───────────────────────────────────
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
}

# ── Pillar 10 — FinOps & Cost Controls ────────────────────────────────────────
variable "cost_controls" {
  description = "Cost management settings."
  type = object({
    cost_center  = optional(string, null)
    project_code = optional(string, null)
  })
  nullable = false
  default  = {}
}

variable "default_tags" {
  description = "Base tags merged onto every resource."
  type        = map(string)
  nullable    = false
  default     = {}
}

# ── VPC configuration ─────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "Hub VPC CIDR block. Must NOT overlap with any spoke VPC CIDR (enforced by OPA). Must be RFC-1918 or RFC-6598 (CG-NAT) range /16–/24."
  type        = string
  nullable    = false
  default     = "100.64.0.0/24"
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "Must be a valid CIDR notation (e.g. 10.0.0.0/16) (Pillar 3 — Network Security & Isolation)."
  }
}

variable "subnets" {
  description = "Subnet tiers for the hub VPC. Each tier gets CIDRs and AZs."
  type = map(object({
    availability_zones = list(string)
    cidrs              = list(string)
  }))
  nullable = false
  default = {
    app = {
      availability_zones = ["us-east-1a", "us-east-1b"]
      cidrs              = ["100.64.0.0/28", "100.64.0.16/28"]
    }
    data = {
      availability_zones = ["us-east-1a", "us-east-1b"]
      cidrs              = ["100.64.0.32/28", "100.64.0.48/28"]
    }
    tgw = {
      availability_zones = ["us-east-1a", "us-east-1b"]
      cidrs              = ["100.64.0.64/28", "100.64.0.80/28"]
    }
  }
}

# ── CIDR overlap prevention (OPA-enforced, not a precondition) ───────────────
# Spoke VPC CIDRs that must not overlap with the hub's CIDR. OPA checks this
# at plan time so the error message is clear and doesn't block non-overlapping
# changes.
variable "spoke_cidrs" {
  description = <<-EOF
    List of spoke VPC CIDRs that this hub must NOT overlap with. OPA denies
    the plan if any spoke CIDR overlaps with the hub VPC CIDR. Required to
    prevent routing conflicts in the hub-and-spoke topology.

    Example:
    ```hcl
    spoke_cidrs = [
      { name = "dev-platform",  cidr = "10.0.0.0/16" },
      { name = "dev-research",  cidr = "10.1.0.0/16" },
      { name = "prod-platform", cidr = "10.10.0.0/16" },
    ]
    ```
  EOF
  type = list(object({
    name = string
    cidr = string
  }))
  nullable = false
  default = [
    { name = "dev-platform", cidr = "10.0.0.0/16" },
    { name = "dev-research", cidr = "10.1.0.0/16" },
    { name = "preprod-platform", cidr = "10.10.0.0/16" },
    { name = "prod-platform", cidr = "10.20.0.0/16" },
    { name = "prod-research", cidr = "10.21.0.0/16" },
    { name = "prod-data-platform", cidr = "10.22.0.0/16" },
    { name = "sandbox-platform", cidr = "10.255.0.0/16" },
  ]
}

# ── Transit Gateway (same-account, the hub's own TG) ─────────────────────────
# The hub VPC attaches to the same-account Transit Gateway created by
# transit-gateway/ terraservice. Since both are in the same AWS account,
# the TG id is available directly (no RAM needed for the hub itself).
# The RAM share from transit-gateway/ is for workload accounts only.
variable "transit_gateway_id" {
  description = "The network-hub Transit Gateway ID (tgw-xxx). Created by transit-gateway/ terraservice."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^tgw-", var.transit_gateway_id))
    error_message = "Must be a valid Transit Gateway ID starting with 'tgw-'."
  }
}

# ── Hub VPC flow log destination (Pillar 5 + Pillar 8) ───────────────────────
variable "flow_log_destination" {
  description = "S3 bucket ARN for VPC flow logs (the immutable audit bucket from baseline)."
  type = object({
    bucket_arn              = string
    bucket_owner_account_id = optional(string, null)
  })
  nullable = true
  default  = null
}

# ── VPC Gateway Endpoints (Pillar 3) ──────────────────────────────────────────
variable "enable_gateway_endpoints" {
  description = "Enable S3 and DynamoDB gateway endpoints in the hub VPC."
  type        = bool
  nullable    = false
  default     = true
}

# ── VPC Interface Endpoints (Pillar 3) ────────────────────────────────────────
variable "interface_endpoints" {
  description = "Interface endpoints to create in the hub VPC. Each needs a service name and subnet tier placement."
  type = list(object({
    service    = string
    subnet_key = optional(string, "app")
  }))
  nullable = false
  default = [
    { service = "ssm", subnet_key = "app" },
    { service = "ssmmessages", subnet_key = "app" },
    { service = "ec2messages", subnet_key = "app" },
    { service = "sts", subnet_key = "app" },
    { service = "kms", subnet_key = "app" },
    { service = "monitoring", subnet_key = "app" },
    { service = "logs", subnet_key = "app" },
    { service = "ecr.api", subnet_key = "app" },
    { service = "ecr.dkr", subnet_key = "app" },
    { service = "secretsmanager", subnet_key = "app" },
  ]
}
