output "key_id" {
  description = "Globally unique identifier for the KMS key."
  value       = aws_kms_key.this.key_id
}

output "key_arn" {
  description = "ARN of the KMS key. Feed this to `kms_key_arn` on consuming modules."
  value       = aws_kms_key.this.arn
}

output "alias_arn" {
  description = "ARN of the key alias."
  value       = aws_kms_alias.this.arn
}

output "key_name" {
  description = "Human-readable name derived from project/environment/classification."
  value       = local.key_name
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation."
  value = {
    environment         = var.environment
    region              = var.region # Pillar 4
    allowed_regions     = var.allowed_regions
    rotation_enabled    = aws_kms_key.this.enable_key_rotation
    deletion_protected  = aws_kms_key.this.deletion_window_in_days >= 30
    encryption_at_rest  = true # this module IS the encryption key
    multi_region        = var.kms.multi_region
    data_classification = var.data_classification
    # A key that disables rotation is a non-compliance the module refuses to create.
    rotation_compliant = aws_kms_key.this.enable_key_rotation == true
  }
}