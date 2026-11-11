# Prod test — prod-grade org trail with PHI data events and sovereign residency.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "prod"
  name                = "prod-trail"
  region              = "us-east-1"
  kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
  data_classification = "phi"
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }
  is_organization_trail = true
  data_events = {
    s3     = ["arn:aws:s3:::"]
    lambda = ["arn:aws:lambda"]
  }
  cloudtrail_insights = {
    insights_type = "ApiCallRateInsight"
  }
  observability = {
    log_retention_days = 365
  }
}

run "test_prod_org_trail" {
  command = plan

  assert {
    condition     = aws_cloudtrail.this.is_organization_trail == true
    error_message = "Prod must use an org-wide trail."
  }
}

run "test_prod_retention" {
  command = plan

  assert {
    condition     = output.compliance_controls.retention_days >= 30
    error_message = "Prod retention must be ≥ 30 days (Pillar 6)."
  }
}

run "test_prod_data_events" {
  command = plan

  assert {
    condition     = length(aws_cloudtrail.this.event_selector) == 1
    error_message = "Data events configured → one event selector block."
  }
}

run "test_prod_tags" {
  command = plan

  assert {
    condition     = local.base_tags.Environment == "prod"
    error_message = "Trail must be tagged with the environment."
  }
}

run "test_prod_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.audit_lock_mode == "COMPLIANCE"
    error_message = "Prod audit lock mode must be COMPLIANCE (Pillar 8)."
  }
  assert {
    condition     = output.compliance_controls.data_classification == "phi"
    error_message = "compliance_controls must report the data classification."
  }
}