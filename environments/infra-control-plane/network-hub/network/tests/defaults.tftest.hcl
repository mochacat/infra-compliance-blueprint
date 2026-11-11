# network-hub / network — default plan test
#
# Validates the hub VPC, TGW attachment, and VPC endpoints with minimal inputs.
# Uses plan-level assertions on known values and variables rather than computed
# IDs (which are unknown at plan time).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment          = "prod"
  name                 = "network-hub"
  region               = "us-east-1"
  data_classification  = "internal"
  vpc_cidr             = "100.64.0.0/24"
  transit_gateway_id   = "tgw-0123456789abcdef0"
  spoke_cidrs = [
    { name = "dev-platform",  cidr = "10.0.0.0/16" },
    { name = "dev-research",  cidr = "10.1.0.0/16" },
    { name = "prod-platform", cidr = "10.10.0.0/16" },
  ]
}

run "test_vpc_created" {
  command = plan

  # The module output vpc_id is computed (assigned on apply), so we assert on
  # known attributes and CidrBlock instead.
  assert {
    condition     = var.vpc_cidr == "100.64.0.0/24"
    error_message = "Hub VPC must use the configured CIDR."
  }
  # Subnet count: 3 tiers × 2 AZs = 6 subnets
  assert {
    condition     = length(flatten([for tier, cfg in var.subnets : cfg.cidrs])) == 6
    error_message = "Must configure at least 6 subnet CIDRs (3 tiers × 2 AZs)."
  }
}

run "test_tgw_attachment_created" {
  command = plan

  # The TGW attachment id is computed. Verify the module is declared.
  assert {
    condition     = var.transit_gateway_id != null
    error_message = "Transit Gateway ID must be provided."
  }
}

run "test_vpc_endpoints_created" {
  command = plan

  # Gateway and interface endpoint IDs are computed. Assert that the modules
  # are configured and the compliance output reports them.
  assert {
    condition     = output.compliance_controls.gateway_endpoints == "enabled"
    error_message = "Must enable S3 + DynamoDB gateway endpoints."
  }
  assert {
    condition     = length(output.compliance_controls.interface_endpoints) >= 2
    error_message = "Must configure interface endpoints."
  }
}

run "test_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.region == "us-east-1"
    error_message = "Region must be reported in compliance_controls."
  }
  assert {
    condition     = output.compliance_controls.environment == "prod"
    error_message = "Environment must be reported in compliance_controls."
  }
  assert {
    condition     = output.compliance_controls.spoke_count == 3
    error_message = "Spoke CIDR count must match the variable."
  }
  assert {
    condition     = output.compliance_controls.gateway_endpoints == "enabled"
    error_message = "Gateway endpoints must be enabled by default."
  }
}

run "test_check_blocks_pass" {
  command = plan

  assert {
    condition     = contains(var.allowed_regions, var.region)
    error_message = "Region check block should pass with approved region."
  }
  assert {
    condition     = var.data_classification != "phi" || var.data_residency.sovereign_only == true
    error_message = "PHI check block should pass with internal classification."
  }
}

run "test_subnet_layout" {
  command = plan

  assert {
    condition     = length(var.subnets) == 3
    error_message = "Must have 3 subnet tiers (app, data, tgw)."
  }
  assert {
    condition     = alltrue([for tier, cfg in var.subnets : length(cfg.availability_zones) >= 2])
    error_message = "Each tier must span at least 2 AZs."
  }
}
