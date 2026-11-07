# Compliance gate test — verifies the module REJECTS non-compliant
# configurations at plan time (Pillar 3 — Network Security & Isolation / Pillar 4 — High Availability & Region Control / Pillar 7 — Data Residency & Sovereignty: prevention, not detection).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "dev"
  name                = "sample-vpc"
  region              = "us-east-1"
  cidr_block          = "10.0.0.0/16"
  data_classification = "internal"
  data_residency = {
    sovereign_only = false
  }
  cost_controls = {
    cost_center  = "sec"
    project_code = "demo"
  }
  subnets = {
    app = {
      availability_zones = ["us-east-1a", "us-east-1b"]
      cidrs              = ["10.0.1.0/24", "10.0.2.0/24"]
    }
  }
}

# 1) A valid baseline plan must succeed (guard against false positives).
run "test_baseline_ok" {
  command = plan

  assert {
    condition     = length(aws_subnet.this) == 2
    error_message = "Baseline should plan 2 subnets."
  }
}

# 2) PHI data without sovereign-only residency must fail (Pillar 7 — Data Residency & Sovereignty).
run "test_phi_not_sovereign_rejected" {
  command = plan
  variables {
    data_classification = "phi"
    data_residency      = { sovereign_only = false }
  }
  expect_failures = [
    aws_vpc.this,
  ]
}

# 3) A region matching the approved pattern but NOT in allowed_regions must
#    fail the precondition (Pillar 4 — High Availability & Region Control). us-east-2 passes the regex, trips the list.
run "test_unapproved_region_rejected" {
  command = plan
  variables {
    region = "us-east-2"
  }
  expect_failures = [
    aws_vpc.this,
  ]
}

# 4) A malformed region (not matching the approved pattern) must fail at
#    variable validation.
run "test_malformed_region_rejected" {
  command = plan
  variables {
    region = "not-a-region"
  }
  expect_failures = [
    var.region,
  ]
}

# 5) A CIDR overlapping a reserved CIDR must fail the overlap precondition.
run "test_cidr_overlap_rejected" {
  command = plan
  variables {
    reserved_cidrs = ["10.0.128.0/17"] # overlaps 10.0.0.0/16
  }
  expect_failures = [
    aws_vpc.this,
  ]
}

# 6) A non-RFC1918 (public) CIDR must fail variable validation.
#    Guard against someone plugging in a globally-routable range or 0.0.0.0/0.
run "test_public_cidr_rejected" {
  command = plan
  variables {
    cidr_block = "11.0.0.0/16"
  }
  expect_failures = [
    var.cidr_block,
  ]
}