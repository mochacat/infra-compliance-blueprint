# Compliance gate test — verifies the module REJECTS non-compliant
# configurations at plan time (Pillar 1: prevention, not detection).

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
  account_id          = "111111111111"
  data_classification = "internal"
  data_residency      = { sovereign_only = false }
  cost_controls       = { cost_center = "sec", project_code = "demo" }
  # Invalid values are overridden per-run below to trigger specific failures.
  kms = {
    iam_principals       = ["arn:aws:iam::111111111111:role/app-role"]
    admins               = ["arn:aws:iam::111111111111:role/app-admin"]
    deletion_window_days = 30
    multi_region         = false
  }
}

# 1) Rotation must not be configurable — any attempt to slip a rotation-off
#    in is structurally refused. Assert the resource is always on.
run "test_no_rotation_knob" {
  command = plan

  assert {
    condition     = aws_kms_key.this.enable_key_rotation == true
    error_message = "Rotation must be locked on (Pillar 1 / SOC 2 CC6.6)."
  }
}

# 2) A multi-region key for PHI data must fail on the resource precondition.
run "test_phi_multi_region_rejected" {
  command = plan
  variables {
    data_classification = "phi"
    data_residency      = { sovereign_only = true, jurisdiction = "US" }
    kms = {
      iam_principals       = ["arn:aws:iam::111111111111:role/app-role"]
      admins               = ["arn:aws:iam::111111111111:role/app-admin"]
      deletion_window_days = 30
      multi_region         = true
    }
  }
  expect_failures = [
    aws_kms_key.this,
  ]
}

# 3) A too-short deletion window must fail (variable validation).
run "test_short_deletion_window_rejected" {
  command = plan
  variables {
    kms = {
      iam_principals       = ["arn:aws:iam::111111111111:role/app-role"]
      admins               = ["arn:aws:iam::111111111111:role/app-admin"]
      deletion_window_days = 14
      multi_region         = false
    }
  }
  expect_failures = [
    var.kms,
  ]
}

# 4) PHI without sovereign-only residency must fail (resource precondition).
run "test_phi_not_sovereign_rejected" {
  command = plan
  variables {
    data_classification = "phi"
    data_residency      = { sovereign_only = false }
    kms = {
      iam_principals       = ["arn:aws:iam::111111111111:role/app-role"]
      admins               = ["arn:aws:iam::111111111111:role/app-admin"]
      deletion_window_days = 30
      multi_region         = false
    }
  }
  expect_failures = [
    aws_kms_key.this,
  ]
}

# 5) Zero principals must fail (variable validation) — no grants by omission.
run "test_no_principals_rejected" {
  command = plan
  variables {
    kms = {
      iam_principals       = []
      admins               = []
      deletion_window_days = 30
      multi_region         = false
    }
  }
  expect_failures = [
    var.kms,
  ]
}

# 6) A region outside allowed_regions must fail (Pillar 4 — High Availability & Region Control (precondition)).
#    `us-east-2` matches the approved-region *pattern* but is NOT in the default
#    allowed_regions, so it trips the resource precondition (not the regex).
run "test_unapproved_region_rejected" {
  command = plan
  variables {
    region = "us-east-2"
  }
  expect_failures = [
    aws_kms_key.this,
  ]
}

# 7) A malformed region (wrong pattern) must fail at variable validation.
run "test_malformed_region_rejected" {
  command = plan
  variables {
    region = "not-a-region"
  }
  expect_failures = [
    var.region,
  ]
}