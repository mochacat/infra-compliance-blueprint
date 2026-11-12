# ─────────────────────────────────────────────────────────────────────────────
# production/platform/compute — outputs
#
# Publishes the ECS execution role ARN to SSM so the data layer can reference
# it for OpenSearch fine-grained access control.
# ─────────────────────────────────────────────────────────────────────────────

output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = module.ecs_cluster.cluster_arn
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = module.ecs_cluster.cluster_name
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation (Pillar 9)."
  value = {
    environment         = var.environment
    data_classification = var.data_classification
    encryption_at_rest  = data.aws_ssm_parameter.kms_key_arn.id != null
    multi_az            = true
  }
}

# ── SSM parameter publication (cross-layer contract) ─────────────────────────
resource "aws_ssm_parameter" "ecs_task_exec_role_arn" {
  name        = "/environments/${var.environment}/${var.business_unit}/ecs-task-exec-role-arn"
  description = "ECS task execution role ARN for ${var.environment}/platform"
  type        = "SecureString"
  value       = data.aws_ssm_parameter.ecs_task_exec_role_arn.value
  key_id      = data.aws_ssm_parameter.kms_key_arn.value
  tags        = local.base_tags
}
