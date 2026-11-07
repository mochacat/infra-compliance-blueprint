# Compliance test — validates the hub REFUSES non-compliant inputs at plan time.
# These expect_failures are the audit gates (Pillar 4/7) for the infra-owned layer.

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
    environment         = "prod"
    name                = "network-hub"
    region              = "us-east-2"
    data_classification = "internal"
    kms_key_arn         = "arn:aws:kms:us-east-1:111122223333:key/12345678-1234-1234-1234-123456789012"
    participants        = ["111122223333"]
  }

  expect_failures = [
    aws_ec2_transit_gateway.this
  ]
}

# ── Expect failure: PHI without sovereign_only (Pillar 7) ────────────────────
run "fail_phi_not_sovereign" {
  command = plan

  variables {
    environment         = "prod"
    name                = "network-hub"
    region              = "us-east-1"
    data_classification = "phi"
    data_residency = {
      sovereign_only = false
    }
    kms_key_arn = "arn:aws:kms:us-east-1:111122223333:key/12345678-1234-1234-1234-123456789012"
    participants = ["111122223333"]
  }

  expect_failures = [
    aws_ec2_transit_gateway.this
  ]
}

# ── Expect failure: no workload account shared the TG (Pillar 2 / Pillar 3) ──
run "fail_no_ram_participants" {
  command = plan

  variables {
    environment         = "prod"
    name                = "network-hub"
    region              = "us-east-1"
    data_classification = "internal"
    kms_key_arn         = "arn:aws:kms:us-east-1:111122223333:key/12345678-1234-1234-1234-123456789012"
    participants        = []
  }

  expect_failures = [
    aws_ram_resource_share.this
  ]
}