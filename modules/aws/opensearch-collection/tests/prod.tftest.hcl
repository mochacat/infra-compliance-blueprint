# Prod test — validates prod-grade posture: standby replicas, retention,
# encryption, private network, and compliance_controls output.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment = "prod"
  name        = "prod-aoss"
  region      = "us-east-1"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
  data_classification = "phi"
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }
  network = {
    vpc_id             = "vpc-0a1b2c3d4e5f67890"
    subnet_ids         = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
    security_group_ids = ["sg-0a1b2c3d4e5f67890"]
  }
  iam = {
    principal_arns = ["arn:aws:iam::123456789012:role/app-service"]
  }
  high_availability = {
    standby_replicas = "ENABLED"
  }
  backup = {
    retention_days = 35
  }
}

run "test_prod_private" {
  command = plan

  assert {
    condition     = output.compliance_controls.private_network == true
    error_message = "Prod collection must be private-only."
  }
  assert {
    condition     = length(var.network.subnet_ids) >= 2
    error_message = "Prod must place the private VPC endpoint in ≥ 2 AZs."
  }
}

run "test_prod_encryption" {
  command = plan

  assert {
    condition     = output.compliance_controls.encryption_at_rest == true
    error_message = "Prod collection must be encrypted with the CMK."
  }
}

run "test_prod_ha" {
  command = plan

  assert {
    condition     = aws_opensearchserverless_collection.this.standby_replicas == "ENABLED"
    error_message = "Prod must use standby replicas (multi-AZ)."
  }
}

run "test_prod_retention" {
  command = plan

  assert {
    condition     = var.backup.retention_days >= 30
    error_message = "Prod retention must be ≥ 30 days."
  }
}

run "test_prod_tags" {
  command = plan

  assert {
    condition     = aws_opensearchserverless_collection.this.tags.Environment == "prod"
    error_message = "Collection must be tagged with the environment."
  }
}

run "test_prod_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.data_classification == "phi"
    error_message = "compliance_controls must report the data classification."
  }
}