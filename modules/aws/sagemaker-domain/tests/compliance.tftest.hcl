# Compliance test — validates the module REFUSES non-compliant inputs at plan
# time. These expect_failures are the audit gates (Pillar 1/3/4/7).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

# ── Expect failure: PHI without sovereign_only (Pillar 7) ────────────────────
run "fail_phi_not_sovereign" {
  command = plan

  variables {
    environment         = "prod"
    name                = "phi-domain"
    region              = "us-east-1"
    kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
    data_classification = "phi"
    data_residency = {
      sovereign_only = false
    }
    network = {
      vpc_id             = "vpc-0a1b2c3d4e5f67890"
      subnet_ids         = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
      security_group_ids = ["sg-0a1b2c3d4e5f67890"]
    }
    iam = {
      execution_role_name = "phi-exec"
    }
  }

  expect_failures = [
    aws_sagemaker_domain.this
  ]
}

# ── Expect failure: region not in allowed_regions (Pillar 4) ─────────────────
run "fail_unapproved_region" {
  command = plan

  variables {
    environment         = "dev"
    name                = "bad-region-domain"
    region              = "us-east-2"
    kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
    data_classification = "internal"
    network = {
      vpc_id             = "vpc-0a1b2c3d4e5f67890"
      subnet_ids         = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
      security_group_ids = ["sg-0a1b2c3d4e5f67890"]
    }
    iam = {
      execution_role_name = "bad-region-exec"
    }
  }

  expect_failures = [
    aws_sagemaker_domain.this
  ]
}

# ── Expect failure: fewer than 2 subnets (Pillar 4) ──────────────────────────
run "fail_single_subnet" {
  command = plan

  variables {
    environment         = "dev"
    name                = "single-az-domain"
    region              = "us-east-1"
    kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
    data_classification = "internal"
    network = {
      vpc_id             = "vpc-0a1b2c3d4e5f67890"
      subnet_ids         = ["subnet-0a1b2c3d4e5f67890"]
      security_group_ids = ["sg-0a1b2c3d4e5f67890"]
    }
    iam = {
      execution_role_name = "single-az-exec"
    }
  }

  expect_failures = [
    aws_sagemaker_domain.this
  ]
}