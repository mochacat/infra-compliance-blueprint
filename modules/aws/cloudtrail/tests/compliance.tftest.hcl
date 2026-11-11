# Compliance test — validates the module REFUSES non-compliant inputs at
# plan time. These expect_failures are the audit gates (Pillar 4/6/8).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

# ── Expect failure: region not in allowed_regions (Pillar 4) ─────────────────
run "fail_unapproved_region" {
  command = plan

  variables {
    environment = "dev"
    name        = "bad-region-trail"
    region      = "us-east-2"
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
  }

  expect_failures = [
    aws_cloudtrail.this
  ]
}

# ── Expect failure: PHI without sovereign_only (Pillar 7) ────────────────────
run "fail_phi_not_sovereign" {
  command = plan

  variables {
    environment         = "prod"
    name                = "phi-trail"
    region              = "us-east-1"
    kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
    data_classification = "phi"
    data_residency = {
      sovereign_only = false
    }
  }

  expect_failures = [
    aws_cloudtrail.this
  ]
}

# ── Expect failure: short audit retention (Pillar 8) ─────────────────────────
run "fail_short_audit_retention" {
  command = plan

  variables {
    environment          = "dev"
    name                 = "short-retention-trail"
    region               = "us-east-1"
    kms_key_arn          = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
    audit_retention_days = 30
  }

  expect_failures = [
    aws_s3_bucket.audit
  ]
}