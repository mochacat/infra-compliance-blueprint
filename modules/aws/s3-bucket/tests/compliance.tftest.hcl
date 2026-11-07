# Compliance gate test — verifies the module REJECTS non-compliant configs.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "dev"
  region              = "us-east-1"
  name                = "compliance-bucket"
  kms_key_arn         = "arn:aws:kms:us-east-1:111111111111:key/aaaa-1111-bbbb-2222"
  data_classification = "internal"
  data_residency      = {}
  cost_controls       = { cost_center = "sec", project_code = "demo" }
}

# 1) Invalid audit retention must fail at variable validation.
run "test_short_audit_retention_rejected" {
  command = plan
  variables {
    audit_bucket         = true
    audit_retention_days = 365
  }
  expect_failures = [
    var.audit_retention_days,
  ]
}

# 2) Invalid audit lock mode must fail.
run "test_invalid_lock_mode_rejected" {
  command = plan
  variables {
    audit_bucket    = true
    audit_lock_mode = "REPLICATE"
  }
  expect_failures = [
    var.audit_lock_mode,
  ]
}

# 3) A non-KMS kms_key_arn must fail (no SSE-S3 fallback).
run "test_encryption_cannot_be_sse_s3" {
  command = plan
  variables {
    kms_key_arn = "not-an-arn"
  }
  expect_failures = [
    var.kms_key_arn,
  ]
}

# 4) PHI without sovereign-only residency must fail (resource precondition).
run "test_phi_not_sovereign_rejected" {
  command = plan
  variables {
    data_classification = "phi"
    data_residency      = { sovereign_only = false }
  }
  expect_failures = [
    aws_s3_bucket.this,
  ]
}

# 5) A region outside allowed_regions must fail (Pillar 4 — High Availability & Region Control (precondition)).
#    `us-east-2` matches the approved-region *pattern* (regex) but is NOT in the
#    default allowed_regions list, so it trips the resource precondition (not the
#    earlier variable-validation regex) — exercising the contains() gate.
run "test_unapproved_region_rejected" {
  command = plan
  variables {
    region = "us-east-2"
  }
  expect_failures = [
    aws_s3_bucket.this,
  ]
}

# 6) A malformed region (wrong pattern) must fail at variable validation.
run "test_malformed_region_rejected" {
  command = plan
  variables {
    region = "not-a-region"
  }
  expect_failures = [
    var.region,
  ]
}