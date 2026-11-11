# ─────────────────────────────────────────────────────────────────────────────
# production/platform/ai — SSM data sources
#
# Reads cross-layer values from SSM Parameter Store, written by iam/ and
# network/ layers.
# ─────────────────────────────────────────────────────────────────────────────

# ── From iam/ ─────────────────────────────────────────────────────────────────
data "aws_ssm_parameter" "kms_key_arn" {
  name = "/environments/${var.environment}/${var.business_unit}/kms-key-arn"
}

data "aws_ssm_parameter" "sagemaker_exec_role_arn" {
  name = "/environments/${var.environment}/${var.business_unit}/sagemaker-exec-role-arn"
}

data "aws_ssm_parameter" "sagemaker_exec_role_name" {
  name = "/environments/${var.environment}/${var.business_unit}/sagemaker-exec-role-name"
}

# ── From network/ ─────────────────────────────────────────────────────────────
data "aws_ssm_parameter" "vpc_id" {
  name = "/environments/${var.environment}/${var.business_unit}/vpc-id"
}

data "aws_ssm_parameter" "app_subnet_ids" {
  name = "/environments/${var.environment}/${var.business_unit}/app-subnet-ids"
}

data "aws_ssm_parameter" "default_sg_id" {
  name = "/environments/${var.environment}/${var.business_unit}/default-sg-id"
}

