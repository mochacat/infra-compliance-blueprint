# Basic usage — compliant private OpenSearch Serverless vector collection.
#
# This example wires the opensearch-collection module to a VPC (caller-owned),
# a KMS key, and an app IAM role. The endpoint + policies are created by the
# module; nothing here can make the collection public or unencrypted.

variable "region" {
  description = "Target region (must be in allowed_regions)."
  type        = string
  default     = "us-east-1"
}

variable "kms_key_arn" {
  description = "Caller-provided CMK ARN for encryption at rest."
  type        = string
}

variable "vpc_id" {
  description = "VPC to place the collection's private endpoint in."
  type        = string
}

variable "subnet_ids" {
  description = "At least 2 private subnets in different AZs."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group(s) allowing access to the endpoint."
  type        = list(string)
}

variable "app_role_arn" {
  description = "IAM role that may read/write the collection (least privilege)."
  type        = string
}