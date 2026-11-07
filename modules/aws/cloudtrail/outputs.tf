# ─────────────────────────────────────────────────────────────────────────────
# Outputs for the cloudtrail module.
# ─────────────────────────────────────────────────────────────────────────────

output "trail_arn" {
  description = "ARN of the CloudTrail trail."
  value       = aws_cloudtrail.this.arn
}

output "trail_home_region" {
  description = "Home region of the trail."
  value       = aws_cloudtrail.this.home_region
}

output "trail_s3_bucket_arn" {
  description = "ARN of the immutable audit S3 bucket."
  value       = aws_s3_bucket.audit.arn
}

output "trail_s3_bucket_id" {
  description = "Name of the audit S3 bucket."
  value       = aws_s3_bucket.audit.id
}

output "log_group_arn" {
  description = "ARN of the CloudTrail CloudWatch log group."
  value       = aws_cloudwatch_log_group.trail.arn
}

output "log_group_name" {
  description = "Name of the CloudTrail CloudWatch log group."
  value       = aws_cloudwatch_log_group.trail.name
}

output "cloudwatch_role_arn" {
  description = "ARN of the CloudTrail → CloudWatch IAM role."
  value       = aws_iam_role.cloudtrail_cloudwatch.arn
}

# ── Pillar 9 — Change management / OPA evaluation ────────────────────────────
# Static facts the eval layer needs to gate enforcement. No computed values so
# the plan-time assertions can read them.
output "compliance_controls" {
  description = "Compliance state for OPA evaluation."
  value = {
    environment           = var.environment
    encryption_at_rest    = true
    multi_region          = true
    log_file_validation   = true
    object_lock_enabled   = true
    secure_transport_deny = true
    retention_days        = var.observability.log_retention_days
    audit_retention_days  = var.audit_retention_days
    audit_lock_mode       = var.audit_lock_mode
    data_classification   = var.data_classification
  }
}