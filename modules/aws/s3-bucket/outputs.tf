output "bucket_id" {
  description = "Bucket name."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Regional domain name."
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation."
  value = {
    environment           = var.environment
    region                = var.region # Pillar 4
    allowed_regions       = var.allowed_regions
    encryption_at_rest    = true
    kms_key_provided      = var.kms_key_arn != null
    secure_transport      = true # EnforceSecureTransport deny present
    public_access_blocked = true
    versioning_enabled    = var.versioning_enabled
    object_lock_mode      = var.audit_bucket ? var.audit_lock_mode : "DISABLED"
    audit_retention_days  = var.audit_bucket ? var.audit_retention_days : null
    data_classification   = var.data_classification
    deletion_protected    = var.audit_bucket
  }
}