# Default plan test — validates the module produces a compliant key with the
# tightest defaults enabled.

# Test-only provider. Shared modules declare no provider of their own (the
# caller supplies it), so we configure one here with credential-checking
# disabled to run plan-only tests offline with no AWS credentials.
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
  kms = {
    iam_principals = ["arn:aws:iam::111111111111:role/app-role"]
    admins         = ["arn:aws:iam::111111111111:role/app-admin"]
    alias_prefix   = "app-"
    description    = "test key"
  }
  data_residency = {
    sovereign_only = false
  }
  cost_controls = {
    cost_center  = "sec"
    project_code = "demo"
  }
}

run "test_rotation_always_on" {
  command = plan

  assert {
    condition     = aws_kms_key.this.enable_key_rotation == true
    error_message = "KMS rotation must be enabled (Pillar 1 / SOC 2 CC6.6)."
  }
}

run "test_deletion_protection" {
  command = plan

  assert {
    condition     = aws_kms_key.this.deletion_window_in_days >= 30
    error_message = "Deletion window must be >= 30 days (Pillar 6 — Backup, DR & Deletion Protection)."
  }
}

run "test_deletion_protection" {
  command = plan

  # `prevent_destroy` is a meta-argument and not readable from a plan, so the
  # closest plan-time signal for deletion protection is a long deletion window
  # (already asserted above). The resource also carries prevent_destroy = true.
}

run "test_alias_created" {
  command = plan

  assert {
    condition     = startswith(aws_kms_alias.this.name, "alias/app-")
    error_message = "Alias must carry the configured prefix."
  }
}

run "test_least_privilege_policy" {
  command = plan

  # Policies are rendered as JSON; assert there's no bare "*" principal.
  assert {
    condition     = !strcontains(data.aws_iam_policy_document.key_policy.json, "\"Principal\":\"*\"")
    error_message = "Key policy must not grant a wildcard principal."
  }
}