# Default plan test — validates the module produces a compliant VPC with the
# tightest defaults (private-only, multi-AZ, no flow log offline).

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
  # flow_log_destination left null (default) — off by default for offline tests.
  subnets = {
    app = {
      availability_zones = ["us-east-1a", "us-east-1b"]
      cidrs              = ["10.0.1.0/24", "10.0.2.0/24"]
    }
    data = {
      availability_zones = ["us-east-1a", "us-east-1b"]
      cidrs              = ["10.0.3.0/24", "10.0.4.0/24"]
    }
  }
}

run "test_dns_support_on" {
  command = plan

  assert {
    condition     = aws_vpc.this.enable_dns_support == true && aws_vpc.this.enable_dns_hostnames == true
    error_message = "DNS support/hostnames must be enabled on the VPC."
  }
}

run "test_subnets_multi_az" {
  command = plan

  # 4 subnets spanning 2 AZs across 2 tiers.
  assert {
    condition     = length(distinct([for s in aws_subnet.this : s.availability_zone])) >= 2
    error_message = "Private subnets must span at least 2 AZs (Pillar 4 — High Availability & Region Control)."
  }
  assert {
    condition     = length(aws_subnet.this) == 4
    error_message = "Expected one subnet per tier per AZ."
  }
}

run "test_subnets_private_only" {
  command = plan

  # Every subnet carries the private network posture tag — no public IPs by default.
  assert {
    condition     = alltrue([for s in aws_subnet.this : s.tags["Network"] == "private"])
    error_message = "All subnets must be private (Pillar 3 — Network Security & Isolation)."
  }
}

run "test_flow_log_disabled_by_default" {
  command = plan

  assert {
    condition     = var.flow_log_destination == null
    error_message = "Flow log destination should default to null (no destination)."
  }
}

run "test_default_security_group_locked" {
  command = plan

  assert {
    condition     = startswith(aws_default_security_group.this.tags["Name"], "sample-vpc-default-sg")
    error_message = "Default SG must be recreated with a module-owned name."
  }
  assert {
    condition     = output.compliance_controls.default_sg_locked == true
    error_message = "compliance_controls must report the default SG locked."
  }
}

run "test_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.subnet_az_count == 2
    error_message = "compliance_controls must report per-AZ spread."
  }
  assert {
    condition     = output.compliance_controls.data_classification == "internal"
    error_message = "compliance_controls must reflect data classification."
  }
  assert {
    condition     = output.compliance_controls.flow_log_destination == "DISABLED"
    error_message = "Flow log state must report DISABLED when no destination."
  }
}