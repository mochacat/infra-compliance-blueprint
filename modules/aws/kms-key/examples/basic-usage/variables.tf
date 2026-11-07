variable "account_id" {
  description = "AWS account ID that owns the key."
  type        = string
}

variable "environment" {
  description = "dev/test/staging/prod/commercial"
  type        = string
  default     = "dev"
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

variable "app_role_arn" {
  description = "ARN of the role allowed to use the key."
  type        = string
}

variable "kms_admin_arn" {
  description = "ARN of the role allowed to administer the key."
  type        = string
}

variable "cost_center" {
  description = "Cost center tag."
  type        = string
  default     = null
}

variable "project_code" {
  description = "Project/tag name for the key alias and tags."
  type        = string
  default     = "demo"
}