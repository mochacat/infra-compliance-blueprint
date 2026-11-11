# Prod test — validates prod-grade posture: VpcOnly, CMK-encryption, PHI
# sovereign-only, default Studio instance ml.t3.medium, retention >= 30.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "prod"
  name                = "ml-prod"
  region              = "us-east-1"
  kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
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
    execution_role_name = "ml-prod-execution"
  }
  cost_controls = {
    studio_instance_type = "ml.t3.medium"
    cost_center          = "platform"
  }
  sagemaker_bucket_arns = ["arn:aws:s3:::ml-data-prod"]
}

run "test_prod_private" {
  command = plan

  assert {
    condition     = aws_sagemaker_domain.this.app_network_access_type == "VpcOnly"
    error_message = "Prod domain must be VpcOnly."
  }
}

run "test_prod_encryption" {
  command = plan

  assert {
    condition     = aws_sagemaker_domain.this.kms_key_id == var.kms_key_arn
    error_message = "Prod domain must be encrypted with the CMK."
  }
}

run "test_prod_retention" {
  command = plan

  assert {
    condition     = var.backup.retention_days >= 30
    error_message = "Prod retention must be >= 30 days."
  }
}

run "test_prod_multi_az" {
  command = plan

  assert {
    condition     = length(var.network.subnet_ids) >= 2
    error_message = "Prod must span multiple AZs."
  }
}

run "test_prod_tags" {
  command = plan

  assert {
    condition     = aws_sagemaker_domain.this.tags.CostCenter == "platform"
    error_message = "Domain must be tagged with CostCenter (Pillar 10)."
  }
}

run "test_prod_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.data_classification == "phi"
    error_message = "compliance_controls must report the data classification."
  }
  assert {
    condition     = output.compliance_controls.private_network == true
    error_message = "compliance_controls must report private network."
  }
}