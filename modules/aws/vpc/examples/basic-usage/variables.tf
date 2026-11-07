variable "environment" {
  description = "dev/test/staging/prod/commercial"
  type        = string
  default     = "dev"
}

variable "name" {
  description = "VPC name prefix."
  type        = string
  default     = "example"
}

variable "region" {
  description = "Target region; must be in allowed_regions."
  type        = string
  default     = "us-east-1"
}

variable "cidr_block" {
  description = "RFC-1918 private range, /16-/28."
  type        = string
  default     = "10.60.0.0/16"
}

variable "reserved_cidrs" {
  description = "Existing CIDRs the VPC must not overlap."
  type        = list(string)
  default     = []
}

variable "data_classification" {
  description = "internal/pii/phi/financial/cardholder"
  type        = string
  default     = "internal"
}

variable "data_residency" {
  description = "Residency constraints."
  type = object({
    sovereign_only = optional(bool, false)
    jurisdiction   = optional(string, null)
  })
  default = {}
}

variable "audit_bucket_arn" {
  description = "Immutable Log Archive bucket ARN for VPC Flow Logs."
  type        = string
  default     = null
}

variable "cost_center" {
  description = "Cost center tag."
  type        = string
  default     = null
}

variable "project_code" {
  description = "Project tag."
  type        = string
  default     = "demo"
}