# Defaults test — validates the module produces a compliant SageMaker Studio
# domain with tight defaults (VpcOnly, CMK-encrypted, multi-AZ, default user,
# least-privilege execution role).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment = "dev"
  name        = "ml-platform"
  region      = "us-east-1"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
  data_classification = "internal"
  network = {
    vpc_id             = "vpc-0a1b2c3d4e5f67890"
    subnet_ids         = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
    security_group_ids = ["sg-0a1b2c3d4e5f67890"]
  }
  iam = {
    execution_role_name = "ml-execution-role"
  }
}

run "test_vpc_only_mode" {
  command = plan

  assert {
    condition     = aws_sagemaker_domain.this.app_network_access_type == "VpcOnly"
    error_message = "Domain must always run VpcOnly (Pillar 3 — Network Security & Isolation)."
  }
  assert {
    condition     = output.compliance_controls.private_network == true
    error_message = "compliance_controls must report private network."
  }
}

run "test_kms_encrypted" {
  command = plan

  assert {
    condition     = aws_sagemaker_domain.this.kms_key_id == var.kms_key_arn
    error_message = "Domain must use the caller-provided KMS key (Pillar 1 — Encryption)."
  }
  assert {
    condition     = output.compliance_controls.encryption_at_rest == true
    error_message = "compliance_controls must report encryption."
  }
}

run "test_multi_az" {
  command = plan

  assert {
    condition     = length(var.network.subnet_ids) >= 2
    error_message = "Domain must span >= 2 subnets for multi-AZ (Pillar 4)."
  }
  assert {
    condition     = output.compliance_controls.multi_az == true
    error_message = "compliance_controls must report multi-AZ."
  }
}

run "test_default_user" {
  command = plan

  assert {
    condition     = length(aws_sagemaker_user_profile.default) == 1
    error_message = "A default user profile must be created."
  }
}

run "test_execution_role_least_privilege" {
  command = plan

  assert {
    condition     = can(regex("\"Resource\": \"\\*\"", local.execution_role_policy)) == false
    error_message = "Execution role policy must not use a wildcard Resource (Pillar 2)."
  }
  assert {
    condition     = aws_iam_role.execution.assume_role_policy != ""
    error_message = "Execution role must exist with an assume policy (Pillar 2 — Access Control & Least Privilege)."
  }
  assert {
    condition     = !can(regex("\"Resource\"\\s*:\\s*\"\\*\"", local.execution_role_policy))
    error_message = "Execution role policy must not use a wildcard Resource (Pillar 2 — Access Control & Least Privilege)."
  }
}

run "test_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.environment == "dev"
    error_message = "compliance_controls must reflect the environment."
  }
  assert {
    condition     = output.compliance_controls.data_classification == "internal"
    error_message = "compliance_controls must report data classification."
  }
}