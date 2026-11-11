# Prod test — validates the module produces a production-grade TGW attachment
# with centralized network inspection enabled (appliance mode) — the pattern a
# regulated org uses in prod for HIPAA 164.312(a)(1) / SOC 2 CC6.7.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment                     = "prod"
  name                            = "prod-core-tgw"
  region                          = "us-east-1"
  transit_gateway_id              = "tgw-0a1b2c3d4e5f67890"
  vpc_id                          = "vpc-0a1b2c3d4e5f67890"
  subnet_ids                      = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891", "subnet-0a1b2c3d4e5f67892"]
  appliance_mode_support          = "enable"
  default_route_table_association = false
  transit_gateway_route_table_id  = "tgw-rtb-0a1b2c3d4e5f67890"
  propagate_to_route_table_id     = "tgw-rtb-0a1b2c3d4e5f67891"
  data_classification             = "internal"
  data_residency = {
    sovereign_only = false
    jurisdiction   = "US"
  }
  cost_controls = {
    cost_center  = "platform"
    project_code = "core"
  }
}

run "test_prod_attachment" {
  command = plan

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.this.appliance_mode_support == "enable"
    error_message = "Appliance mode must be enabled for centralized inspection in prod."
  }
  assert {
    condition     = length(aws_ec2_transit_gateway_vpc_attachment.this.subnet_ids) >= 2
    error_message = "Attachment must span at least 2 AZs."
  }
  assert {
    condition     = length(aws_ec2_transit_gateway_route_table_association.this) == 1
    error_message = "Custom route table association should be created."
  }
  assert {
    condition     = length(aws_ec2_transit_gateway_route_table_propagation.this) == 1
    error_message = "Route table propagation should be created."
  }
}

run "test_prod_tags" {
  command = plan

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.this.tags["Environment"] == "prod"
    error_message = "Environment tag must be prod."
  }
  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.this.tags["CostCenter"] == "platform"
    error_message = "CostCenter tag must be set."
  }
}

run "test_prod_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.centralized_inspection == true
    error_message = "Centralized inspection must be reported as enabled."
  }
  assert {
    condition     = output.compliance_controls.route_table_override == "custom"
    error_message = "Route table override must be reported as custom."
  }
}