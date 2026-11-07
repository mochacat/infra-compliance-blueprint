variable "environment" {
  type    = string
  default = "dev"
}

variable "name" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "kms_key_arn" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "data_classification" {
  type    = string
  default = "internal"
}

variable "alarm_topic_arn" {
  type    = string
  default = null
}