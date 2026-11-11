# Compliance test — validates the module REFUSES non-compliant inputs at
# plan time. These expect_failures are the audit gates (Pillar 3 — Network Security & Isolation / Pillar 4 — High Availability & Region Control / Pillar 7 — Data Residency & Sovereignty).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

# ── Expect failure: interface endpoint in a single AZ (Pillar 4 — High Availability & Region Control) ────────────
# Single-subnet interface endpoint trips the lifecycle precondition.
run "fail_interface_single_az" {
  command = plan

  variables {
    environment = "dev"
    name        = "single-az-endpoint"
    region      = "us-east-1"
    vpc_id      = "vpc-0a1b2c3d4e5f67890"
    interface_endpoints = [
      {
        service    = "sts"
        subnet_ids = ["subnet-0a1b2c3d4e5f67890"]
      },
    ]
    security_group_ids  = ["sg-0a1b2c3d4e5f67890"]
    data_classification = "internal"
  }

  expect_failures = [
    aws_vpc_endpoint.interface["sts"]
  ]
}

# ── Expect failure: region not in allowed_regions (Pillar 4 — High Availability & Region Control) ─────────────────
# us-east-2 passes the pattern regex but is NOT in the default allowed_regions,
# so it trips the lifecycle precondition on the gateway endpoint resource.
run "fail_unapproved_region" {
  command = plan

  variables {
    environment = "dev"
    name        = "bad-region"
    region      = "us-east-2"
    vpc_id      = "vpc-0a1b2c3d4e5f67890"
    gateway_endpoints = [
      {
        service         = "s3"
        route_table_ids = ["rtb-0a1b2c3d4e5f67890"]
      },
    ]
    data_classification = "internal"
  }

  expect_failures = [
    aws_vpc_endpoint.gateway["s3"]
  ]
}

# ── Expect failure: PHI without sovereign_only (Pillar 7 — Data Residency & Sovereignty) ────────────────────
run "fail_phi_not_sovereign" {
  command = plan

  variables {
    environment = "prod"
    name        = "phi-endpoint"
    region      = "us-east-1"
    vpc_id      = "vpc-0a1b2c3d4e5f67890"
    gateway_endpoints = [
      {
        service         = "s3"
        route_table_ids = ["rtb-0a1b2c3d4e5f67890"]
      },
    ]
    data_classification = "phi"
    data_residency = {
      sovereign_only = false
    }
  }

  expect_failures = [
    aws_vpc_endpoint.gateway["s3"]
  ]
}