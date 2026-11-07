# Production plan test — strictest inputs, verifies the key stays compliant
# when configured for production data.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "prod"
  region              = "us-east-1"
  account_id          = "222222222222"
  data_classification = "phi"
  kms = {
    iam_principals       = ["arn:aws:iam::222222222222:role/svc-reader"]
    admins               = ["arn:aws:iam::222222222222:role/kms-admin"]
    alias_prefix         = "prod-"
    description          = "production PHI key"
    deletion_window_days = 30
    multi_region         = false
  }
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }
  cost_controls = {
    cost_center  = "ops"
    project_code = "prod-app"
  }
}

run "test_prod_rotation" {
  command = plan

  assert {
    condition     = aws_kms_key.this.enable_key_rotation == true
    error_message = "Rotation must be on in production."
  }
}

run "test_prod_key_enabled" {
  command = plan

  assert {
    condition     = aws_kms_key.this.is_enabled == true
    error_message = "Key must be enabled."
  }
}

run "test_phi_not_multi_region" {
  command = plan

  assert {
    condition     = aws_kms_key.this.multi_region == false
    error_message = "PHI key must not be multi-region (Pillar 7 — Data Residency & Sovereignty)."
  }
}

run "test_outputs" {
  command = plan

  assert {
    condition     = output.compliance_controls.rotation_compliant == true
    error_message = "compliance_controls must report rotation compliant."
  }
}