output "domain_id" {
  description = "SageMaker Domain ID."
  value       = aws_sagemaker_domain.this.id
}

output "domain_arn" {
  description = "ARN of the SageMaker Domain."
  value       = aws_sagemaker_domain.this.arn
}

output "domain_url" {
  description = "Studio UI URL."
  value       = aws_sagemaker_domain.this.url
}

output "home_efs_file_system_id" {
  description = "ID of the EFS file system created for the domain home directories (encrypted with the CMK)."
  value       = aws_sagemaker_domain.this.home_efs_file_system_id
}

output "default_user_profile_name" {
  description = "Name of the default user profile (empty if not created)."
  value       = var.create_default_user ? aws_sagemaker_user_profile.default[0].user_profile_name : ""
}

output "execution_role_name" {
  description = "Name of the dedicated SageMaker execution role."
  value       = aws_iam_role.execution.name
}

output "execution_role_arn" {
  description = "ARN of the dedicated SageMaker execution role."
  value       = aws_iam_role.execution.arn
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation."
  value = {
    environment         = var.environment
    region              = var.region
    encryption_at_rest  = var.kms_key_arn != null
    private_network     = true # VpcOnly, always
    multi_az            = length(var.network.subnet_ids) >= 2
    retention_days      = var.backup.retention_days
    data_classification = var.data_classification
  }
}