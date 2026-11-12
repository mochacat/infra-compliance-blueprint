variable "environment" {
  description = "Environment: dev, test, staging, prod, preprod, sandbox, commercial"
  type        = string
  validation {
    condition     = contains(["dev", "test", "staging", "prod", "preprod", "sandbox", "commercial"], var.environment)
    error_message = "Must be one of: dev, test, staging, prod, preprod, sandbox, commercial."
  }
}

variable "vpc_name" {
  description = "Name of the workload VPC."
  type        = string
}

variable "region" {
  description = "Target region."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "The workload VPC ID."
  type        = string
}

variable "route_table_ids" {
  description = "Route tables to add the S3 gateway prefix-list route to."
  type        = list(string)
}

variable "endpoint_subnet_ids" {
  description = "Subnets (≥ 2 AZs) for interface endpoints."
  type        = list(string)
}

variable "endpoint_security_group_ids" {
  description = "Security groups for interface endpoints (least privilege)."
  type        = list(string)
}

variable "private_bucket_arn" {
  description = "S3 bucket ARN the S3 endpoint policy should allow access to."
  type        = string
}

variable "data_classification" {
  description = "Data classification."
  type        = string
  default     = "internal"
}

variable "cost_center" {
  description = "Cost center tag."
  type        = string
  default     = "platform"
}

variable "project_code" {
  description = "Project code tag."
  type        = string
  default     = "core"
}