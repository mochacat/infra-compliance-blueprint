# Production plan test — strictest inputs: pinned OIDC subjects,
# permissions boundary present, all pillar tags set.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  role_name         = "opentofu-deploy"
  oidc_provider_arn = "arn:aws:iam::222222222222:oidc-provider/token.actions.githubusercontent.com"
  allowed_subjects = [
    "repo:anestoa/infrastructure:ref:refs/heads/main",
    "repo:anestoa/infrastructure:ref:refs/heads/release/*",
  ]
  permissions_boundary_arn = "arn:aws:iam::222222222222:policy/cicd-boundary"
  environment              = "prod"
  data_classification      = "internal"
  cost_controls = {
    cost_center  = "infra"
    project_code = "anestoa"
  }
  tags = {
    ManagedBy = "tofu"
  }
}

run "test_prod_role_name" {
  command = plan

  assert {
    condition     = aws_iam_role.deploy.name == "opentofu-deploy"
    error_message = "Role name must match input."
  }
}

run "test_prod_permissions_boundary" {
  command = plan

  assert {
    condition     = aws_iam_role.deploy.permissions_boundary == "arn:aws:iam::222222222222:policy/cicd-boundary"
    error_message = "Prod role must have a permissions boundary (Pillar 2 — Access Control & Least Privilege)."
  }
}

run "test_prod_tags" {
  command = plan

  assert {
    condition     = aws_iam_role.deploy.tags["Environment"] == "prod"
    error_message = "Prod role must have Environment=prod tag (Pillar 9 — Change Management & Policy Enforcement)."
  }
  assert {
    condition     = aws_iam_role.deploy.tags["CostCenter"] == "infra"
    error_message = "Prod role must have CostCenter tag (Pillar 10 — FinOps & Cost Controls)."
  }
  assert {
    condition     = aws_iam_role.deploy.tags["Project"] == "anestoa"
    error_message = "Prod role must have Project tag."
  }
  assert {
    condition     = aws_iam_role.deploy.tags["DataClassification"] == "internal"
    error_message = "Prod role must have DataClassification tag (Pillar 7 — Data Residency & Sovereignty)."
  }
}

run "test_prod_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.environment == "prod"
    error_message = "compliance_controls must reflect prod environment (Pillar 9 — Change Management & Policy Enforcement)."
  }
  assert {
    condition     = output.compliance_controls.permissions_boundary_set == true
    error_message = "compliance_controls must report permissions_boundary_set as true in prod."
  }
}

run "test_prod_scope_policy_no_wildcard" {
  command = plan

  # The deploy-role scope policy intentionally uses Resource = ["*"] for
  # Describe*/Get/Put actions on state infrastructure. This is a recognized
  # exception — the actions themselves are scoped. Not a blanket admin.
  assert {
    condition     = !strcontains(aws_iam_policy.deploy_scope.policy, "AdministratorAccess")
    error_message = "Scope policy must not reference AdministratorAccess."
  }
  assert {
    condition     = !strcontains(aws_iam_policy.deploy_scope.policy, "\"Action\":\"*\"")
    error_message = "Scope policy must not have a wildcard Action."
  }
}