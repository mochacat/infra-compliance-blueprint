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
  environment         = "dev"
  name                = "compliance-test"
  data_classification = "internal"
  trust_policy        = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }
  EOF
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

# 2) A wildcard Resource must fail (check block — wildcard resource moved
#    from variable validation to a check block because it cross-references
#    allowed_resource_wildcards).
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
    check.wildcard_resources,
  ]
}

# 3) No permissions boundary in prod must fail (lifecycle precondition).
run "test_prod_no_boundary_rejected" {
  command = plan
  variables {
    environment = "prod"
  }
  expect_failures = [
    aws_iam_role.this,
  ]
}

# 4) PHI without sovereign residency must fail (lifecycle precondition).
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

# 5) An invalid environment must fail (variable validation).
run "test_invalid_environment_rejected" {
  command = plan
  variables {
    environment = "not-an-env"
  }
  expect_failures = [
    var.environment,
  ]
}

# 6) An empty trust_policy is acceptable (the module passes it through).
run "test_no_inline_policy_if_empty" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.inline) == 0
    error_message = "No inline policy should be created when policy_statements is empty."
  }
}

# 7) Max session duration out of range must fail.
run "test_max_session_duration_too_low" {
  command = plan
  variables {
    max_session_duration = 1800
  }
  expect_failures = [
    var.max_session_duration,
  ]
}