# Compliance gate test — verifies the module REJECTS missing required
# inputs and produces a scoped policy.

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
  tags              = {}
}

# 1) The scope policy must not reference AdministratorAccess.
run "test_no_administrator_access" {
  command = plan

  assert {
    condition     = !strcontains(aws_iam_policy.deploy_scope.policy, "AdministratorAccess")
    error_message = "Scope policy must not reference AdministratorAccess (Pillar 2 — Access Control & Least Privilege)."
  }
}

# 2) The trust policy must be valid JSON.
run "test_trust_policy_valid_json" {
  command = plan

  assert {
    condition     = can(jsondecode(aws_iam_role.deploy.assume_role_policy))
    error_message = "Trust policy must be valid JSON."
  }
}

# 3) The scope policy must be valid JSON.
run "test_scope_policy_valid_json" {
  command = plan

  assert {
    condition     = can(jsondecode(aws_iam_policy.deploy_scope.policy))
    error_message = "Scope policy must be valid JSON."
  }
}

# 4) An empty allowed_subjects list should still create the role.
run "test_empty_allowed_subjects" {
  command = plan
  variables {
    allowed_subjects = []
  }

  assert {
    condition     = can(aws_iam_role.deploy.name)
    error_message = "Role must still be created even with empty allowed_subjects."
  }
}

# 5) Invalid environment must be rejected.
run "test_invalid_environment_rejected" {
  command = plan
  variables {
    environment = "invalid"
  }
  expect_failures = [
    var.environment,
  ]
}

# 6) PHI without sovereign_only must be rejected (Pillar 7 — Data Residency & Sovereignty).
run "test_phi_not_sovereign_rejected" {
  command = plan
  variables {
    environment         = "dev"
    data_classification = "phi"
    data_residency = {
      sovereign_only = false
    }
  }
  expect_failures = [
    resource.aws_iam_role.deploy,
  ]
}