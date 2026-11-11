# ─────────────────────────────────────────────────────────────────────────────
# development/platform/data — SSM data sources
#
# Reads cross-layer values from SSM Parameter Store, written by iam/ and
# network/ layers. This decouples state files — data/ does not need iam/ or
# network/'s state to exist, only their SSM parameters to have been written.
# ─────────────────────────────────────────────────────────────────────────────

# ── From iam/ ─────────────────────────────────────────────────────────────────
data "aws_ssm_parameter" "kms_key_arn" {
  name = "/environments/${var.environment}/${var.business_unit}/kms-key-arn"
}

data "aws_ssm_parameter" "rds_proxy_role_arn" {
  name = "/environments/${var.environment}/${var.business_unit}/rds-proxy-role-arn"
}

# ── From network/ ─────────────────────────────────────────────────────────────
data "aws_ssm_parameter" "vpc_id" {
  name = "/environments/${var.environment}/${var.business_unit}/vpc-id"
}

data "aws_ssm_parameter" "data_subnet_ids" {
  name = "/environments/${var.environment}/${var.business_unit}/data-subnet-ids"
}

data "aws_ssm_parameter" "default_sg_id" {
  name = "/environments/${var.environment}/${var.business_unit}/default-sg-id"
}

# ── From compute/ ──────────────────────────────────────────────────────────────
data "aws_ssm_parameter" "ecs_task_exec_role_arn" {
  name = "/environments/${var.environment}/${var.business_unit}/ecs-task-exec-role-arn"
}

# ── From ai/ ───────────────────────────────────────────────────────────────────
data "aws_ssm_parameter" "sagemaker_exec_role_arn" {
  name = "/environments/${var.environment}/${var.business_unit}/sagemaker-exec-role-arn"
}