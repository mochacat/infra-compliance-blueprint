variable "region" {
  description = "AWS region for the management account baseline (home region)."
  type        = string
  default     = "us-east-1"
  validation {
    condition     = contains(["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"], var.region)
    error_message = "Management region must be an approved region."
  }
}

variable "environment" {
  description = "Environment: dev, test, staging, prod, preprod, sandbox, commercial"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "test", "staging", "prod", "preprod", "sandbox", "commercial"], var.environment)
    error_message = "Must be one of: dev, test, staging, prod, preprod, sandbox, commercial."
  }
}

variable "management_account_id" {
  description = "The org management account ID (the account tofu runs from)."
  type        = string
  nullable    = false
}

variable "log_archive_account_id" {
  description = "Account ID of the Log Archive account. Null skips the audit bucket."
  type        = string
  default     = null
}

variable "security_account_id" {
  description = "Account ID of the Security account. Null skips GuardDuty/Security Hub delegation."
  type        = string
  default     = null
}

variable "audit_log_bucket" {
  description = "Audit log S3 bucket name in the Log Archive account."
  type        = string
  default     = "anestoa-audit-logs"
}

variable "log_retention_days" {
  description = "Log retention in days for the audit bucket (minimum 7 years / 2557 for compliance)."
  type        = number
  default     = 2557
  validation {
    condition     = var.log_retention_days >= 2557
    error_message = "Audit log retention must be at least 2557 days (7 years) for compliance."
  }
}

variable "audit_lock_mode" {
  description = "Object Lock mode for the audit bucket: COMPLIANCE or GOVERNANCE."
  type        = string
  default     = "COMPLIANCE"
  validation {
    condition     = contains(["COMPLIANCE", "GOVERNANCE"], var.audit_lock_mode)
    error_message = "Must be COMPLIANCE or GOVERNANCE."
  }
}

variable "cloudtrail_org" {
  description = "Deploy an organization-wide CloudTrail from the management account."
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention" {
  description = "Retention days for the org CloudTrail CloudWatch log group."
  type        = number
  default     = 90
  validation {
    condition     = var.cloudwatch_log_retention >= 30
    error_message = "CloudTrail log retention must be at least 30 days."
  }
}

variable "guardduty_delegate" {
  description = "Delegate GuardDuty org administration to the Security account."
  type        = bool
  default     = true
}

variable "securityhub_delegate" {
  description = "Delegate Security Hub org administration to the Security account."
  type        = bool
  default     = true
}

variable "config_org" {
  description = "Enable organization-wide AWS Config from the management account."
  type        = bool
  default     = true
}

# ── OIDC / CI-CD ──
variable "cicd_role_name" {
  description = "Name of the cross-account deploy role created in each account."
  type        = string
  default     = "opentofu-deploy"
}

variable "cicd_oidc_provider_arn" {
  description = "ARN of the GitHub (or Atlantis) OIDC provider for the deploy role. Null creates a role with no trust for now."
  type        = string
  default     = null
}

variable "cicd_oidc_provider_url" {
  description = "URL of the OIDC provider (e.g. token.actions.githubusercontent.com)."
  type        = string
  default     = null
}

# ── Tags ──
variable "default_tags" {
  description = "Tags applied to all baseline resources."
  type        = map(string)
  default = {
    ManagedBy          = "tofu"
    Purpose            = "landing-zone-baseline"
    DataClassification = "internal"
    CostCenter         = "platform"
  }
}