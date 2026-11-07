# Default plan test — validates the module produces a deploy role with
# default OIDC trust and scoped inline policy (no AdministratorAccess).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  role_name         = "opentofu-deploy"
  oidc_provider_arn = "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com"
  allowed_subjects  = ["repo:org/repo:ref:refs/heads/main"]
  environment       = "dev"
  tags = {
    ManagedBy = "tofu"
  }
}

run "test_role_created" {
  command = plan

  assert {
    condition     = aws_iam_role.deploy.name == "opentofu-deploy"
    error_message = "Role name must match input."
  }
}

run "test_role_description_contains_environment" {
  command = plan

  assert {
    condition     = strcontains(aws_iam_role.deploy.description, "dev")
    error_message = "Role description must contain the environment (Pillar 9 — Change Management & Policy Enforcement)."
  }
}

run "test_trust_policy_uses_oidc" {
  command = plan

  assert {
    condition     = strcontains(aws_iam_role.deploy.assume_role_policy, "Federated")
    error_message = "Trust policy must use Federated OIDC principal."
  }
  assert {
    condition     = strcontains(aws_iam_role.deploy.assume_role_policy, "token.actions.githubusercontent.com")
    error_message = "Trust policy must reference the GitHub OIDC provider."
  }
}

run "test_scope_policy_attached" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy_attachment.deploy) > 0
    error_message = "Scope policy must be attached to the role."
  }
}

run "test_no_admin_access" {
  command = plan

  assert {
    condition     = !strcontains(aws_iam_policy.deploy_scope.policy, "AdministratorAccess")
    error_message = "Scope policy must not reference AdministratorAccess."
  }
}

run "test_pillar_tags_present" {
  command = plan

  assert {
    condition     = aws_iam_role.deploy.tags["Environment"] == "dev"
    error_message = "Role must have Environment=dev tag (Pillar 9 — Change Management & Policy Enforcement)."
  }
  assert {
    condition     = aws_iam_role.deploy.tags["DataClassification"] == "internal"
    error_message = "Role must have DataClassification tag (Pillar 7 — Data Residency & Sovereignty)."
  }
  assert {
    condition     = aws_iam_role.deploy.tags["ManagedBy"] == "tofu"
    error_message = "Role must have ManagedBy=tofu tag."
  }
}

run "test_compliance_controls_output" {
  command = plan

  assert {
    condition     = output.compliance_controls.environment == "dev"
    error_message = "compliance_controls must reflect the environment (Pillar 9 — Change Management & Policy Enforcement)."
  }
  assert {
    condition     = output.compliance_controls.data_classification == "internal"
    error_message = "compliance_controls must reflect data_classification."
  }
  assert {
    condition     = output.compliance_controls.permissions_boundary_set == false
    error_message = "compliance_controls must report permissions_boundary_set correctly."
  }
}

run "test_outputs" {
  command = plan

  assert {
    condition     = output.role_name == "opentofu-deploy"
    error_message = "Output role_name must match."
  }
}