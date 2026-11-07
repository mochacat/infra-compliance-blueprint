# Basic SageMaker Domain example
# Provision an always-private, CMK-encrypted SageMaker Studio domain.
# Network (VPC, subnets, SageMaker endpoints) is provided by the caller /
# network layer; this example references static placeholders.

module "sagemaker_domain" {
  source = "../../"

  environment = "dev"
  name        = "ml-platform"
  region      = var.region

  kms_key_arn = var.kms_key_arn

  network = {
    vpc_id             = var.vpc_id
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  iam = {
    execution_role_name = "ml-platform-exec"
  }

  sagemaker_bucket_arns = var.sagemaker_bucket_arns

  default_tags = {
    Team = "ml"
  }
}