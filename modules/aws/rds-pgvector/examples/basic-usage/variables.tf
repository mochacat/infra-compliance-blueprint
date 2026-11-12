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

variable "kms_key_arn" {
  description = "CMK ARN for encryption at rest."
  type        = string
}

variable "secret_name" {
  description = "Name of the Secrets Manager secret holding DB credentials."
  type        = string
}

variable "master_username" {
  description = "Master DB username."
  type        = string
  default     = "appuser"
}

variable "data_subnet_ids" {
  description = "Private subnet IDs (≥ 2 AZs) for the cluster."
  type        = list(string)
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to reach PostgreSQL."
  type        = list(string)
  default     = []
}

variable "replica_count" {
  description = "Number of cluster instances (HA)."
  type        = number
  default     = 1
}

variable "retention_days" {
  description = "Backup retention (≥ 30)."
  type        = number
  default     = 30
}

variable "vector_dimensions" {
  description = "pgvector vector dimensions."
  type        = number
  default     = 1536
}

variable "index_type" {
  description = "pgvector index type (hnsw or ivfflat)."
  type        = string
  default     = "hnsw"
}

variable "instance_class" {
  description = "DB instance class for provisioned (prod) mode."
  type        = string
  default     = null
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