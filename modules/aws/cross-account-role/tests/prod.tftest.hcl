# Production plan test — strictest inputs: permissions boundary required,
# trust conditions pinned, PHI with sovereign residency.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment = "prod"
  name        = "shared-analytics"
  source_account_arns = [
    "arn:aws:iam::222222222222:role/DataPipeline",
    "arn:aws:iam::333333333333:role/ETLWorker",
  ]
  trust_conditions = {
    test     = "StringEquals"
    variable = "sts:ExternalId"
    values   = ["prod-external-id-2024"]
  }
  data_classification = "phi"
  policy_statements = [
    {
      sid       = "WriteAnalytics"
      effect    = "Allow"
      actions   = ["s3:PutObject", "s3:GetObject"]
      resources = ["arn:aws:s3:::analytics-prod/*"]
    }
  ]
  permissions_boundary_arn = "arn:aws:iam::222222222222:policy/prod-boundary"
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }
  cost_controls = {
    cost_center  = "data"
    project_code = "analytics"
  }
  default_tags = {
    Team = "platform"
  }
}

run "test_prod_role_name" {
  command = plan

  assert {
    condition     = aws_iam_role.this.name == "cross-account-shared-analytics"
    error_message = "Role name must include cross-account prefix."
  }
}

run "test_prod_permissions_boundary" {
  command = plan

  assert {
    condition     = aws_iam_role.this.permissions_boundary == "arn:aws:iam::222222222222:policy/prod-boundary"
    error_message = "Prod role must have a permissions boundary (Pillar 2 — Access Control & Least Privilege)."
  }
}

run "test_trust_conditions_applied" {
  command = plan

  assert {
    condition     = strcontains(aws_iam_role.this.assume_role_policy, "sts:ExternalId")
    error_message = "Trust policy must include the ExternalId condition."
  }
}

run "test_prod_tags" {
  command = plan

  assert {
    condition     = aws_iam_role.this.tags["Environment"] == "prod"
    error_message = "Prod role must have Environment=prod tag."
  }
  assert {
    condition     = aws_iam_role.this.tags["DataClassification"] == "phi"
    error_message = "Prod role must have DataClassification=phi tag."
  }
  assert {
    condition     = aws_iam_role.this.tags["Team"] == "platform"
    error_message = "Prod role must carry default_tags."
  }
}

run "test_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.trust_condition_set == true
    error_message = "compliance_controls must report trust condition set."
  }
  assert {
    condition     = output.compliance_controls.permissions_boundary_set == true
    error_message = "compliance_controls must report boundary set."
  }
  assert {
    condition     = output.compliance_controls.source_account_count == 2
    error_message = "compliance_controls must reflect source account count."
  }
}