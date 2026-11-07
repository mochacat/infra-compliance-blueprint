# ─────────────────────────────────────────────────────────────────────────────
# development/platform/compute — SSM data sources
#
# Reads cross-layer values from SSM Parameter Store, written by iam/ and
# network/ layers.
# ─────────────────────────────────────────────────────────────────────────────

# ── From iam/ ─────────────────────────────────────────────────────────────────
data "aws_ssm_parameter" "kms_key_arn" {
  name = "/environments/${var.environment}/platform/kms-key-arn"
}

data "aws_ssm_parameter" "ecs_task_exec_role_arn" {
  name = "/environments/${var.environment}/platform/ecs-task-exec-role-arn"
}

data "aws_ssm_parameter" "ecs_service_role_arn" {
  name = "/environments/${var.environment}/platform/ecs-service-role-arn"
}

# ── From network/ ─────────────────────────────────────────────────────────────
data "aws_ssm_parameter" "vpc_id" {
  name = "/environments/${var.environment}/platform/vpc-id"
}

data "aws_ssm_parameter" "app_subnet_ids" {
  name = "/environments/${var.environment}/platform/app-subnet-ids"
}

data "aws_ssm_parameter" "default_sg_id" {
  name = "/environments/${var.environment}/platform/default-sg-id"
}

