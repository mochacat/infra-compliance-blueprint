# ─────────────────────────────────────────────────────────────────────────────
# development/platform/ai — outputs
#
# Publishes the SageMaker execution role ARN to SSM so the data layer can
# reference it for OpenSearch fine-grained access control.
# ─────────────────────────────────────────────────────────────────────────────

output "sagemaker_domain_id" {
  description = "SageMaker Studio domain ID."
  value       = module.sagemaker_domain.domain_id
}

output "sagemaker_domain_arn" {
  description = "SageMaker Studio domain ARN."
  value       = module.sagemaker_domain.domain_arn
}

output "sagemaker_default_user_profile_name" {
  description = "Default user profile name."
  value       = module.sagemaker_domain.default_user_profile_name
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation (Pillar 9)."
  value = {
    environment         = var.environment
    data_classification = var.data_classification
    encryption_at_rest  = data.aws_ssm_parameter.kms_key_arn.id != null
    vpc_only            = true
    deletion_protection = true
  }
}

# ── SSM parameter publication (cross-layer contract) ─────────────────────────
resource "aws_ssm_parameter" "sagemaker_exec_role_arn" {
  name        = "/environments/${var.environment}/${var.business_unit}/sagemaker-exec-role-arn"
  description = "SageMaker execution role ARN for ${var.environment}/platform"
  type        = "SecureString"
  value       = data.aws_ssm_parameter.sagemaker_exec_role_arn.value
  key_id      = data.aws_ssm_parameter.kms_key_arn.value
  tags        = local.base_tags
}
