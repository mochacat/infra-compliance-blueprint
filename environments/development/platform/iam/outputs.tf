# ─────────────────────────────────────────────────────────────────────────────
# development/platform/iam — outputs + SSM publication
#
# Published SSM parameters:
#   /environments/<env>/platform/kms-key-arn
#   /environments/<env>/platform/ecs-task-exec-role-arn
#   /environments/<env>/platform/ecs-task-exec-role-name
#   /environments/<env>/platform/ecs-service-role-arn
#   /environments/<env>/platform/sagemaker-exec-role-arn
#   /environments/<env>/platform/sagemaker-exec-role-name
#   /environments/<env>/platform/rds-proxy-role-arn
#
# Downstream layers read these via aws_ssm_parameter data sources,
# never via terraform_remote_state.
# ─────────────────────────────────────────────────────────────────────────────

# ── Standard outputs (for terraform_remote_state within the same apply chain) ─
output "app_kms_key_arn" {
  description = "KMS key ARN for encryption at rest in this account."
  value       = local.app_kms_key_arn
}

output "ecs_task_exec_role_arn" {
  description = "ARN of the ECS task execution role."
  value       = module.ecs_task_exec_role.role_arn
}

output "ecs_task_exec_role_name" {
  description = "Name of the ECS task execution role."
  value       = module.ecs_task_exec_role.role_name
}

output "ecs_service_role_arn" {
  description = "ARN of the ECS service (app) role."
  value       = module.ecs_service_role.role_arn
}

output "sagemaker_execution_role_arn" {
  description = "ARN of the SageMaker execution role."
  value       = module.sagemaker_execution_role.role_arn
}

output "sagemaker_execution_role_name" {
  description = "Name of the SageMaker execution role."
  value       = module.sagemaker_execution_role.role_name
}

output "rds_proxy_role_arn" {
  description = "ARN of the RDS Proxy IAM role."
  value       = module.rds_proxy_role.role_arn
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation (Pillar 9)."
  value = {
    environment              = var.environment
    data_classification      = var.data_classification
    permissions_boundary_set = var.permissions_boundary_arn != null
    ecs_task_exec_role_arn   = module.ecs_task_exec_role.role_arn
    ecs_service_role_arn     = module.ecs_service_role.role_arn
    sagemaker_exec_role_arn  = module.sagemaker_execution_role.role_arn
    rds_proxy_role_arn       = module.rds_proxy_role.role_arn
  }
}

# ── SSM parameter publication (cross-layer contract) ─────────────────────────
locals {
  ssm_base_path = "/environments/${var.environment}/${var.business_unit}"
}

resource "aws_ssm_parameter" "kms_key_arn" {
  name        = "${local.ssm_base_path}/kms-key-arn"
  description = "KMS key ARN for ${var.environment}/platform"
  type        = "String"
  value       = local.app_kms_key_arn
  key_id      = local.app_kms_key_arn
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "ecs_task_exec_role_arn" {
  name        = "${local.ssm_base_path}/ecs-task-exec-role-arn"
  description = "ECS task execution role ARN for ${var.environment}/platform"
  type        = "String"
  value       = module.ecs_task_exec_role.role_arn
  key_id      = local.app_kms_key_arn
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "ecs_task_exec_role_name" {
  name        = "${local.ssm_base_path}/ecs-task-exec-role-name"
  description = "ECS task execution role name for ${var.environment}/platform"
  type        = "String"
  value       = module.ecs_task_exec_role.role_name
  key_id      = local.app_kms_key_arn
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "ecs_service_role_arn" {
  name        = "${local.ssm_base_path}/ecs-service-role-arn"
  description = "ECS service role ARN for ${var.environment}/platform"
  type        = "String"
  value       = module.ecs_service_role.role_arn
  key_id      = local.app_kms_key_arn
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "sagemaker_exec_role_arn" {
  name        = "${local.ssm_base_path}/sagemaker-exec-role-arn"
  description = "SageMaker execution role ARN for ${var.environment}/platform"
  type        = "String"
  value       = module.sagemaker_execution_role.role_arn
  key_id      = local.app_kms_key_arn
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "sagemaker_exec_role_name" {
  name        = "${local.ssm_base_path}/sagemaker-exec-role-name"
  description = "SageMaker execution role name for ${var.environment}/platform"
  type        = "String"
  value       = module.sagemaker_execution_role.role_name
  key_id      = local.app_kms_key_arn
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "rds_proxy_role_arn" {
  name        = "${local.ssm_base_path}/rds-proxy-role-arn"
  description = "RDS Proxy role ARN for ${var.environment}/platform"
  type        = "String"
  value       = module.rds_proxy_role.role_arn
  key_id      = local.app_kms_key_arn
  tags        = local.base_tags
}
