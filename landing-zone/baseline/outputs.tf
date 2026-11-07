output "audit_bucket" {
  description = "Immutable audit log bucket name and ARN."
  value = var.log_archive_account_id != null ? {
    id  = aws_s3_bucket.audit[0].id
    arn = aws_s3_bucket.audit[0].arn
  } : null
}

output "audit_kms_key_arn" {
  description = "ARN of the audit key encrypting the audit bucket."
  value       = var.log_archive_account_id != null ? aws_kms_key.audit[0].arn : null
}

output "cloudtrail" {
  description = "Organization CloudTrail state."
  value = (var.cloudtrail_org && var.log_archive_account_id != null) ? {
    name      = aws_cloudtrail.org[0].name
    arn       = aws_cloudtrail.org[0].arn
    log_group = aws_cloudwatch_log_group.org_trail[0].name
  } : null
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID in the Security account."
  value       = (var.guardduty_delegate && var.security_account_id != null) ? aws_guardduty_detector.org[0].id : null
}

output "deploy_role_arn" {
  description = "ARN of the CI/CD deploy role in the management account."
  value       = var.cicd_oidc_provider_arn != null ? module.deploy_role_management[0].role_arn : null
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation."
  value = {
    environment            = var.environment
    object_lock_mode       = var.audit_lock_mode
    audit_retention_days   = var.log_retention_days
    cloudtrail_enabled     = var.cloudtrail_org && var.log_archive_account_id != null
    guardduty_delegated    = var.guardduty_delegate && var.security_account_id != null
    securityhub_delegated  = var.securityhub_delegate && var.security_account_id != null
    config_enabled         = var.config_org
    audit_bucket_immutable = var.log_archive_account_id != null
  }
}