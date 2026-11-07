# Default plan test — validates the module produces a scoped role with
# no wildcards, no managed policies by default.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "dev"
  name                = "app-role"
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
  policy_statements = [
    {
      sid       = "S3Read"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:ListBucket"]
      resources = ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"]
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
    condition     = aws_iam_role.this.name == "app-role"
    error_message = "Role name must match input."
  }
}

run "test_trust_policy_applied" {
  command = plan

  assert {
    condition     = strcontains(aws_iam_role.this.assume_role_policy, "ec2.amazonaws.com")
    error_message = "Trust policy must reference the expected service."
  }
}

run "test_inline_policy_created" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.inline) == 1
    error_message = "Inline policy must be created when policy_statements provided."
  }
}

run "test_inline_policy_no_wildcards" {
  command = plan

  assert {
    condition     = !strcontains(aws_iam_role_policy.inline[0].policy, "\"*\"")
    error_message = "Inline policy must not contain wildcard Action or Resource (Pillar 2 — Access Control & Least Privilege)."
  }
}

run "test_no_managed_policies_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy_attachment.managed) == 0
    error_message = "No managed policies should be attached by default."
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
    condition     = output.compliance_controls.environment == "dev"
    error_message = "compliance_controls must reflect environment."
  }
  assert {
    condition     = output.compliance_controls.policy_statement_count == 1
    error_message = "compliance_controls must reflect policy statement count."
  }
  assert {
    condition     = output.compliance_controls.permissions_boundary_set == false
    error_message = "compliance_controls must report boundary not set (dev)."
  }
}