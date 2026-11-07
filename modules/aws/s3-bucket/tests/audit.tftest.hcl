# Audit-bucket test — Object Lock in COMPLIANCE mode, 7-year retention,
# deletion protection (Pillar 8 / HIPAA 164.312(b)).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment          = "prod"
  region               = "us-east-1"
  name                 = "myco-audit-logs"
  kms_key_arn          = "arn:aws:kms:us-east-1:111111111111:key/eeee-ffff-1111-2222"
  audit_bucket         = true
  audit_lock_mode      = "COMPLIANCE"
  audit_retention_days = 2557
  data_classification  = "internal"
  data_residency       = {}
  cost_controls        = { cost_center = "platform", project_code = "audit" }
}

run "test_object_lock_compliance_mode" {
  command = plan

  assert {
    condition     = anytrue(flatten([for c in aws_s3_bucket_object_lock_configuration.this : [for r in c.rule : r.default_retention[0].mode == "COMPLIANCE"]]))
    error_message = "Audit bucket must use Object Lock COMPLIANCE mode (HIPAA 164.312(c)(2))."
  }
}

run "test_object_lock_retention" {
  command = plan

  assert {
    condition     = anytrue(flatten([for c in aws_s3_bucket_object_lock_configuration.this : [for r in c.rule : r.default_retention[0].days >= 2557]]))
    error_message = "Audit retention must be at least 2557 days (7 years)."
  }
}

run "test_audit_versioning" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be on for audit buckets."
  }
}