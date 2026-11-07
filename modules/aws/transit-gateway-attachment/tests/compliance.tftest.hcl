# Compliance test — validates that the module REFUSES non-compliant inputs at
# plan time. These expect_failures are the audit gates (Pillar 3 — Network Security & Isolation / Pillar 4 — High Availability & Region Control / Pillar 7 — Data Residency & Sovereignty).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

# ── Expect failure: PHI without sovereign_only (Pillar 7 — Data Residency & Sovereignty) ────────────────────
run "fail_phi_not_sovereign" {
  command = plan

  variables {
    environment         = "prod"
    name                = "phi-violation"
    region              = "us-east-1"
    transit_gateway_id  = "tgw-0a1b2c3d4e5f67890"
    vpc_id              = "vpc-0a1b2c3d4e5f67890"
    subnet_ids          = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
    data_classification = "phi"
    data_residency = {
      sovereign_only = false
    }
  }

  expect_failures = [
    aws_ec2_transit_gateway_vpc_attachment.this
  ]
}

# ── Expect failure: single-AZ attachment (Pillar 4 — High Availability & Region Control) ──────────────────────────
run "fail_single_az" {
  command = plan

  variables {
    environment         = "dev"
    name                = "single-az"
    region              = "us-east-1"
    transit_gateway_id  = "tgw-0a1b2c3d4e5f67890"
    vpc_id              = "vpc-0a1b2c3d4e5f67890"
    subnet_ids          = ["subnet-0a1b2c3d4e5f67890"]
    data_classification = "internal"
  }

  expect_failures = [
    aws_ec2_transit_gateway_vpc_attachment.this
  ]
}

# ── Expect failure: region not in allowed_regions (Pillar 4 — High Availability & Region Control) ─────────────────
# us-east-2 passes the region *pattern* regex but is NOT in the default
# allowed_regions list, so it trips the lifecycle precondition (on the
# resource) rather than the variable validation.
run "fail_unapproved_region" {
  command = plan

  variables {
    environment         = "dev"
    name                = "bad-region"
    region              = "us-east-2"
    transit_gateway_id  = "tgw-0a1b2c3d4e5f67890"
    vpc_id              = "vpc-0a1b2c3d4e5f67890"
    subnet_ids          = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
    data_classification = "internal"
  }

  expect_failures = [
    aws_ec2_transit_gateway_vpc_attachment.this
  ]
}