# Defaults test — validates the module produces compliant VPC endpoints with
# tight defaults (no endpoints by default, proper tags, compliance_controls).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "dev"
  name                = "sample-endpoints"
  region              = "us-east-1"
  vpc_id              = "vpc-0a1b2c3d4e5f67890"
  data_classification = "internal"
}

run "test_no_endpoints_by_default" {
  command = plan

  assert {
    condition     = length(aws_vpc_endpoint.gateway) == 0
    error_message = "No gateway endpoints should be created by default."
  }
  assert {
    condition     = length(aws_vpc_endpoint.interface) == 0
    error_message = "No interface endpoints should be created by default."
  }
}

run "test_compliance_controls_empty" {
  command = plan

  assert {
    condition     = output.compliance_controls.environment == "dev"
    error_message = "compliance_controls must reflect environment."
  }
  assert {
    condition     = output.endpoint_count == 0
    error_message = "endpoint_count must be 0 with no endpoints."
  }
  assert {
    condition     = output.compliance_controls.interface_ha == true
    error_message = "interface_ha must be true (vacuously) with no endpoints."
  }
}