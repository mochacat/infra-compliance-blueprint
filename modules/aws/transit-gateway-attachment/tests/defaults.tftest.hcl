# Defaults test — validates the module produces a compliant TGW attachment with
# tight defaults (multi-AZ subnets, no appliance mode by default, dns support on,
# standard tags).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "dev"
  name                = "sample-tgw-attach"
  region              = "us-east-1"
  transit_gateway_id  = "tgw-0a1b2c3d4e5f67890"
  vpc_id              = "vpc-0a1b2c3d4e5f67890"
  subnet_ids          = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
  data_classification = "internal"
}

run "test_attachment_created" {
  command = plan

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.this != null
    error_message = "Attachment resource must exist."
  }
  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.this.transit_gateway_id == var.transit_gateway_id
    error_message = "Attachment must reference the provided TGW ID."
  }
  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.this.vpc_id == var.vpc_id
    error_message = "Attachment must reference the provided VPC ID."
  }
}

run "test_dns_support_on" {
  command = plan

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.this.dns_support == "enable"
    error_message = "DNS support must be enabled by default."
  }
}

run "test_appliance_mode_off_by_default" {
  command = plan

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.this.appliance_mode_support == "disable"
    error_message = "Appliance/inspection mode should be off by default."
  }
}

run "test_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.environment == "dev"
    error_message = "compliance_controls must reflect environment."
  }
  assert {
    condition     = output.compliance_controls.centralized_inspection == false
    error_message = "Centralized inspection should be disabled by default."
  }
  assert {
    condition     = output.compliance_controls.subnet_az_count == 2
    error_message = "compliance_controls must report ≥ 2 AZ spread."
  }
}
