# Defaults test — validates the module produces a compliant, immutable,
# org-wide audit trail with defaults: multi-region, log-file validation,
# KMS-encrypted, Object Lock COMPLIANCE, versioning on.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment = "dev"
  name        = "org-trail"
  region      = "us-east-1"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
}

run "test_multi_region" {
  command = plan

  assert {
    condition     = aws_cloudtrail.this.is_multi_region_trail == true
    error_message = "Trail must be multi-region by default (Pillar 5/8)."
  }
}

run "test_log_file_validation" {
  command = plan

  assert {
    condition     = aws_cloudtrail.this.enable_log_file_validation == true
    error_message = "Log file validation must be enabled (Pillar 8)."
  }
}

run "test_org_trail_default" {
  command = plan

  assert {
    condition     = aws_cloudtrail.this.is_organization_trail == true
    error_message = "Trail must be an organization trail by default."
  }
}

run "test_s3_encryption_kms" {
  command = plan

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.audit.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    error_message = "Audit bucket must use KMS encryption (Pillar 1)."
  }
}

run "test_cloudwatch_encryption" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.trail.kms_key_id == var.kms_key_arn
    error_message = "CloudWatch log group must be KMS-encrypted (Pillar 1)."
  }
}

run "test_object_lock" {
  command = plan

  assert {
    condition     = aws_s3_bucket.audit.object_lock_enabled == true
    error_message = "Audit bucket must have Object Lock (Pillar 8)."
  }
  assert {
    condition     = aws_s3_bucket_object_lock_configuration.audit.rule[0].default_retention[0].mode == "COMPLIANCE"
    error_message = "Object Lock must be COMPLIANCE by default (Pillar 8)."
  }
}

run "test_versioning" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.audit.versioning_configuration[0].status == "Enabled"
    error_message = "Audit bucket versioning must be enabled (Pillar 6/8)."
  }
}

run "test_public_access_blocked" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.audit.block_public_acls == true
    error_message = "Public ACLs must be blocked (Pillar 3)."
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.audit.restrict_public_buckets == true
    error_message = "Public buckets must be restricted (Pillar 3)."
  }
}

run "test_trail_bucket_policy_secure_transport" {
  command = plan

  assert {
    condition     = output.compliance_controls.secure_transport_deny == true
    error_message = "Bucket policy must deny non-SecureTransport (Pillar 1)."
  }
}

run "test_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.object_lock_enabled == true
    error_message = "compliance_controls must report object lock."
  }
  assert {
    condition     = output.compliance_controls.multi_region == true
    error_message = "compliance_controls must report multi-region."
  }
  assert {
    condition     = output.compliance_controls.encryption_at_rest == true
    error_message = "compliance_controls must report encryption."
  }
}