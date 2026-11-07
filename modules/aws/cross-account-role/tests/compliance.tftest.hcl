# Compliance gate test — verifies the module REJECTS non-compliant
# configurations at plan time.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment = "dev"
  name        = "compliance-test"
  source_account_arns = [
    "arn:aws:iam::111111111111:root",
  ]
  data_classification = "internal"
  policy_statements   = []
  cost_controls       = { cost_center = null, project_code = null }
}

# 1) A wildcard Action must fail (variable validation).
run "test_wildcard_action_rejected" {
  command = plan
  variables {
    policy_statements = [
      {
        sid       = "Bad"
        effect    = "Allow"
        actions   = ["*"]
        resources = ["arn:aws:s3:::my-bucket/*"]
      }
    ]
  }
  expect_failures = [
    var.policy_statements,
  ]
}

# 2) A wildcard Resource must fail (variable validation).
run "test_wildcard_resource_rejected" {
  command = plan
  variables {
    policy_statements = [
      {
        sid       = "Bad"
        effect    = "Allow"
        actions   = ["s3:GetObject"]
        resources = ["*"]
      }
    ]
  }
  expect_failures = [
    var.policy_statements,
  ]
}

# 3) A malformed source account ARN must fail (variable validation).
run "test_malformed_source_account_rejected" {
  command = plan
  variables {
    source_account_arns = ["not-an-arn"]
  }
  expect_failures = [
    var.source_account_arns,
  ]
}

# 4) No permissions boundary in prod must fail (lifecycle precondition).
run "test_prod_no_boundary_rejected" {
  command = plan
  variables {
    environment = "prod"
  }
  expect_failures = [
    aws_iam_role.this,
  ]
}

# 5) PHI without sovereign residency must fail (lifecycle precondition).
run "test_phi_not_sovereign_rejected" {
  command = plan
  variables {
    data_classification = "phi"
    data_residency      = { sovereign_only = false }
  }
  expect_failures = [
    aws_iam_role.this,
  ]
}

# 6) An invalid environment must fail (variable validation).
run "test_invalid_environment_rejected" {
  command = plan
  variables {
    environment = "not-an-env"
  }
  expect_failures = [
    var.environment,
  ]
}

# 7) No inline policy when policy_statements is empty.
run "test_no_inline_policy_if_empty" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.inline) == 0
    error_message = "No inline policy should be created when policy_statements is empty."
  }
}