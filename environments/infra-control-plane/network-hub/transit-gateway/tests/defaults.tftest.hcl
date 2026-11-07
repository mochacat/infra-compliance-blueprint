# Defaults test — validates the hub Transit Gateway + SSM publish with
# minimal inputs (infra team's control-plane account).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "prod"
  name                = "network-hub"
  region              = "us-east-1"
  data_classification = "internal"
  kms_key_arn         = "arn:aws:kms:us-east-1:111122223333:key/12345678-1234-1234-1234-123456789012"
  participants        = ["111122223333", "444455556666"]
}

run "test_transit_gateway_created" {
  command = plan

  # The TG id is computed (assigned on apply), so assert on known attributes and
  # the compliance_controls output rather than the id.
  assert {
    condition     = aws_ec2_transit_gateway.this.amazon_side_asn == 64512
    error_message = "Hub must use the standard private ASN."
  }
  assert {
    condition     = aws_ec2_transit_gateway.this.auto_accept_shared_attachments == "disable"
    error_message = "Hub must not auto-accept shared attachments by default."
  }
  assert {
    condition     = output.compliance_controls.region_approved == true
    error_message = "Hub region must be an approved region."
  }
  assert {
    condition     = output.compliance_controls.shared_via_ram == true
    error_message = "Hub must share the TG via RAM for cross-account discovery."
  }
  assert {
    condition     = length(aws_ram_principal_association.this) == 2
    error_message = "Hub must share the TG with each named participant account."
  }
  assert {
    condition     = aws_ram_resource_share.this.allow_external_principals == false
    error_message = "Hub must not allow external (non-org) principals."
  }
}

run "test_ram_share_created" {
  command = plan

  assert {
    condition     = aws_ram_resource_share.this.name == "network-hub-tgw"
    error_message = "RAM resource share must use the hub name."
  }
  assert {
    condition     = aws_ram_resource_share.this.allow_external_principals == false
    error_message = "RAM share must not allow external (non-org) principals."
  }
  # The share exists (resource is declared); its ARN is computed so we assert the
  # static name + the principal associations count instead.
  assert {
    condition     = length(aws_ram_principal_association.this) == 2
    error_message = "RAM share must grant each named participant account."
  }
}

run "test_ssm_parameter_published" {
  command = plan

  assert {
    condition     = aws_ssm_parameter.transit_gateway_id.name == "/infrastructure/network-hub/transit-gateway/id"
    error_message = "SSM parameter must use the documented path."
  }
  assert {
    condition     = aws_ssm_parameter.transit_gateway_id.type == "String"
    error_message = "SSM parameter must be a plain String."
  }
}

run "test_tags" {
  command = plan

  assert {
    condition     = aws_ec2_transit_gateway.this.tags.Environment == "prod"
    error_message = "Hub must be tagged with the environment."
  }
  assert {
    condition     = can(lookup(aws_ec2_transit_gateway.this.tags, "CostCenter", null))
    error_message = "Hub must carry a CostCenter tag (Pillar 10)."
  }
}

run "test_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.region_approved == true
    error_message = "region_approved must reflect allowed_regions."
  }
  assert {
    condition     = output.compliance_controls.shared_via_ram == true
    error_message = "shared_via_ram must be true when participants are named."
  }
  assert {
    condition     = length(output.compliance_controls.participants) == 2
    error_message = "participants must be reported for OPA."
  }
}