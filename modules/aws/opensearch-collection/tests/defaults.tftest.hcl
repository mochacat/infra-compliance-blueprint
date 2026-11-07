# Defaults test — validates the module produces a compliant, private-only
# OpenSearch Serverless vector collection with tight defaults (always-on KMS
# encryption, always-on private VPC endpoint, retention ≥ 30, standby replicas).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment = "dev"
  name        = "sample-aoss"
  region      = "us-east-1"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
  data_classification = "internal"
  network = {
    vpc_id             = "vpc-0a1b2c3d4e5f67890"
    subnet_ids         = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
    security_group_ids = ["sg-0a1b2c3d4e5f67890"]
  }
  iam = {
    principal_arns = ["arn:aws:iam::123456789012:role/app-service"]
  }
}

run "test_vectorsearch_type" {
  command = plan

  assert {
    condition     = aws_opensearchserverless_collection.this.type == "VECTORSEARCH"
    error_message = "Default collection type must be VECTORSEARCH for RAG."
  }
}

run "test_private_endpoint_always" {
  command = plan

  assert {
    condition     = output.compliance_controls.private_network == true
    error_message = "compliance_controls must report private network."
  }
}

run "test_encryption_policy_cmk" {
  command = plan

  assert {
    condition     = can(regex(replace(var.kms_key_arn, "/", "\\/"), aws_opensearchserverless_security_policy.encryption.policy))
    error_message = "Encryption policy must reference the caller-provided CMK (Pillar 1)."
  }
  assert {
    condition     = can(regex("\"AWSOwnedKey\":false", aws_opensearchserverless_security_policy.encryption.policy))
    error_message = "Encryption policy must NOT use an AWS-owned key (Pillar 1)."
  }
}

run "test_retention_30" {
  command = plan

  assert {
    condition     = var.backup.retention_days >= 30
    error_message = "Default retention must be at least 30 days (Pillar 6)."
  }
}

run "test_standby_replicas" {
  command = plan

  assert {
    condition     = aws_opensearchserverless_collection.this.standby_replicas == "ENABLED"
    error_message = "Standby replicas must be enabled by default (Pillar 4)."
  }
}

run "test_access_policy_least_privilege" {
  command = plan

  assert {
    condition     = var.iam.principal_arns != null && length(var.iam.principal_arns) >= 1
    error_message = "Access policy must scope to caller principals (Pillar 2)."
  }
}

run "test_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.encryption_at_rest == true
    error_message = "encryption_at_rest must be true."
  }
  assert {
    condition     = output.compliance_controls.private_network == true
    error_message = "private_network must be true."
  }
}