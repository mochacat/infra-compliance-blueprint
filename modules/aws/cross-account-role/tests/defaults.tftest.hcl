# Default plan test — validates the module produces a cross-account role
# with scoped trust and inline policy.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment = "dev"
  name        = "log-reader"
  source_account_arns = [
    "arn:aws:iam::111111111111:root",
  ]
  data_classification = "internal"
  policy_statements = [
    {
      sid       = "ReadLogs"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:ListBucket"]
      resources = ["arn:aws:s3:::log-archive/*"]
    }
  ]
  cost_controls = {
    cost_center  = "sec"
    project_code = "demo"
  }
}

run "test_role_created" {
  command = plan

  assert {
    condition     = aws_iam_role.this.name == "cross-account-log-reader"
    error_message = "Role name must include cross-account prefix."
  }
}

run "test_trust_policy_source_accounts" {
  command = plan

  assert {
    condition     = strcontains(aws_iam_role.this.assume_role_policy, "arn:aws:iam::111111111111:root")
    error_message = "Trust policy must reference source accounts."
  }
}

run "test_inline_policy_created" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.inline) == 1
    error_message = "Inline policy must be created when policy_statements provided."
  }
}

run "test_tags_applied" {
  command = plan

  assert {
    condition     = aws_iam_role.this.tags["Environment"] == "dev"
    error_message = "Role must have Environment tag."
  }
  assert {
    condition     = aws_iam_role.this.tags["DataClassification"] == "internal"
    error_message = "Role must have DataClassification tag."
  }
  assert {
    condition     = aws_iam_role.this.tags["CostCenter"] == "sec"
    error_message = "Role must have CostCenter tag."
  }
}

run "test_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.source_account_count == 1
    error_message = "compliance_controls must reflect source account count."
  }
  assert {
    condition     = output.compliance_controls.permissions_boundary_set == false
    error_message = "compliance_controls must report boundary not set (dev)."
  }
  assert {
    condition     = output.compliance_controls.policy_statement_count == 1
    error_message = "compliance_controls must reflect policy statement count."
  }
}