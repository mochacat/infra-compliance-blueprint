variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "kms_key_arn" {
  description = "CMK ARN for encryption at rest"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

variable "sagemaker_bucket_arns" {
  type    = list(string)
  default = []
}