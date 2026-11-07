variable "region" {
  description = "AWS region for the management account. Should be home region."
  type        = string
  default     = "us-east-1"
  validation {
    condition     = contains(["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"], var.region)
    error_message = "Management account region must be an approved region."
  }
}

variable "org_name" {
  description = "Display name for the AWS Organization"
  type        = string
  default     = "Anestoa"
}

variable "org_email" {
  description = "Email address for the management account. Used as the org root email."
  type        = string
  nullable    = false
}

variable "account_email_domain" {
  description = "Email domain for member account aliases (e.g., 'anestoa.io'). Accounts use account-<name>@<domain>."
  type        = string
  nullable    = false
}

variable "account_email_prefix" {
  description = "Prefix for account email aliases (e.g., 'aws-' → aws-security@domain.com)"
  type        = string
  default     = "aws-"
}

variable "allowed_regions" {
  description = "Regions approved for workload deployment. Enforced by RestrictRegions SCP."
  type        = list(string)
  default     = ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"]
}

variable "audit_log_bucket_name" {
  description = "Name for the central audit log bucket in the Log Archive account"
  type        = string
  default     = "anestoa-audit-logs"
}

variable "sso_instance_arn" {
  description = "ARN of an existing AWS IAM Identity Center instance to enable. Leave null to skip."
  type        = string
  default     = null
}