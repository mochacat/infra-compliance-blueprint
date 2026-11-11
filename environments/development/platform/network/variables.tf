# ─────────────────────────────────────────────────────────────────────────────
# development/platform/network — VPC, TGW attachment, and VPC endpoints
#
# Pillar coverage:
#   1  Encryption:   flow logs encrypted via SSE-S3 to immutable audit bucket
#   3  Network:      private subnets, no public IPs, VPC endpoints
#   4  HA:           multi-AZ subnets enforced (≥2 AZs per tier)
#   5  Observability: VPC flow logs to centralized audit bucket
#   7  Residency:    data_classification + data_residency gates
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
  description = "Approved regions."
  type        = list(string)
  nullable    = false
  default     = ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"]
}

# ── Pillar 1 — Encryption (KMS CMK for SSM parameter encryption) ──────────────
variable "kms_key_arn" {
  description = "CMK ARN for encrypting SSM parameters published by this layer."
  type        = string
  nullable    = false
}

# ── Pillar 7 — Data Residency & Sovereignty ───────────────────────────────────
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

# ── VPC configuration ─────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "VPC CIDR block. Must be RFC-1918 private range /16–/28."
  type        = string
  nullable    = false
  default     = "10.0.0.0/16"
}

variable "reserved_cidrs" {
  description = "Existing CIDRs this VPC must not overlap (hub VPC, other spokes)."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "subnets" {
  description = "Subnet tiers: app, data, tgw. Each tier gets CIDRs and AZs."
  type = map(object({
    availability_zones = list(string)
    cidrs              = list(string)
  }))
  nullable = false
  default = {
    app = {
      availability_zones = ["us-east-1a", "us-east-1b"]
      cidrs              = ["10.0.1.0/24", "10.0.2.0/24"]
    }
    data = {
      availability_zones = ["us-east-1a", "us-east-1b"]
      cidrs              = ["10.0.3.0/24", "10.0.4.0/24"]
    }
    tgw = {
      availability_zones = ["us-east-1a", "us-east-1b"]
      cidrs              = ["10.0.5.0/24", "10.0.6.0/24"]
    }
  }
}

# ── VPC flow log destination (Pillar 5 + Pillar 8) ────────────────────────────
variable "flow_log_destination" {
  description = "S3 bucket ARN for VPC flow logs (the immutable audit bucket)."
  type = object({
    bucket_arn              = string
    bucket_owner_account_id = optional(string, null)
  })
  nullable = true
  default  = null
}

# ── Transit Gateway (Pillar 3) ────────────────────────────────────────────────
variable "transit_gateway_id" {
  description = "The Network Hub Transit Gateway ID (tgw-xxx). Read via terraform_remote_state from infra-control-plane."
  type        = string
  nullable    = true
  default     = null
}

variable "appliance_mode_support" {
  description = "Enable centralized network inspection via TGW appliance mode."
  type        = string
  nullable    = false
  default     = "disable"
  validation {
    condition     = contains(["enable", "disable"], var.appliance_mode_support)
    error_message = "Must be 'enable' or 'disable'."
  }
}

# ── VPC Gateway Endpoints (Pillar 3) ──────────────────────────────────────────
# These are free and should always be enabled for S3 + DynamoDB.
variable "enable_gateway_endpoints" {
  description = "Enable S3 and DynamoDB gateway endpoints."
  type        = bool
  nullable    = false
  default     = true
}

# ── VPC Interface Endpoints (Pillar 3) ────────────────────────────────────────
# Enable SSM, STS, KMS, CloudWatch, ECR, and Secrets Manager by default.
variable "interface_endpoints" {
  description = "Interface endpoints to create. Each needs a service name."
  type = list(object({
    service    = string
    subnet_key = optional(string, "app") # which subnet tier to place in
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
    { service = "aoss", subnet_key = "data" },
  ]
}
