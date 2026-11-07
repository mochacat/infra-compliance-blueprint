# Prod test — validates the module creates gateway + interface endpoints with
# full compliance (multi-AZ interface endpoints, private DNS, least-privilege
# policy, tags).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "prod"
  name                = "prod-core-endpoints"
  region              = "us-east-1"
  vpc_id              = "vpc-0a1b2c3d4e5f67890"
  gateway_endpoints = [
    {
      service         = "s3"
      route_table_ids = ["rtb-0a1b2c3d4e5f67890", "rtb-0a1b2c3d4e5f67891"]
    },
  ]
  interface_endpoints = [
    {
      service             = "ssm"
      subnet_ids          = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
      private_dns_enabled = true
    },
    {
      service             = "sts"
      subnet_ids          = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
      private_dns_enabled = true
    },
  ]
  security_group_ids = ["sg-0a1b2c3d4e5f67890"]
  endpoint_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = ["arn:aws:s3:::my-secure-bucket/*"]
      },
    ]
  }
  data_classification = "internal"
  data_residency = {
    sovereign_only = false
    jurisdiction   = "US"
  }
  cost_controls = {
    cost_center  = "platform"
    project_code = "core"
  }
}

run "test_gateway_endpoint_created" {
  command = plan

  assert {
    condition     = length(aws_vpc_endpoint.gateway) == 1
    error_message = "One gateway endpoint should be created."
  }
  assert {
    condition     = aws_vpc_endpoint.gateway["s3"].vpc_endpoint_type == "Gateway"
    error_message = "Gateway endpoint must be type Gateway."
  }
  assert {
    condition     = aws_vpc_endpoint.gateway["s3"].service_name == "com.amazonaws.us-east-1.s3"
    error_message = "Service name must be correct."
  }
}

run "test_interface_endpoint_created" {
  command = plan

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 2
    error_message = "Two interface endpoints should be created."
  }
  assert {
    condition     = aws_vpc_endpoint.interface["ssm"].vpc_endpoint_type == "Interface"
    error_message = "Interface endpoint must be type Interface."
  }
  assert {
    condition     = aws_vpc_endpoint.interface["ssm"].private_dns_enabled == true
    error_message = "Private DNS must be enabled."
  }
  assert {
    condition     = length(aws_vpc_endpoint.interface["ssm"].subnet_ids) >= 2
    error_message = "Interface endpoint must span ≥ 2 subnets (Pillar 4 — High Availability & Region Control)."
  }
}

run "test_prod_tags" {
  command = plan

  assert {
    condition     = aws_vpc_endpoint.gateway["s3"].tags["Environment"] == "prod"
    error_message = "Environment tag must be prod."
  }
  assert {
    condition     = aws_vpc_endpoint.gateway["s3"].tags["CostCenter"] == "platform"
    error_message = "CostCenter tag must be set."
  }
}

run "test_endpoint_policy_applied" {
  command = plan

  assert {
    condition     = output.compliance_controls.endpoint_policy_set == true
    error_message = "endpoint_policy_set must be true when a policy is provided."
  }
  assert {
    condition     = can(jsondecode(aws_vpc_endpoint.gateway["s3"].policy))
    error_message = "Gateway endpoint policy must be valid JSON."
  }
}

run "test_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.interface_ha == true
    error_message = "interface_ha must be true."
  }
  assert {
    condition     = output.endpoint_count == 3
    error_message = "endpoint_count must be 3 (1 gateway + 2 interface)."
  }
  assert {
    condition     = output.compliance_controls.interface_endpoints[0] == "ssm"
    error_message = "interface_endpoints must list ssm."
  }
}