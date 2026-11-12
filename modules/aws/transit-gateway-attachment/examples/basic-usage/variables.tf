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

variable "vpc_cidr_block" {
  description = "CIDR for the workload VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "transit_gateway_id" {
  description = "The Network Hub's Transit Gateway ID."
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