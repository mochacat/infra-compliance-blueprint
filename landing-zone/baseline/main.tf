# ─────────────────────────────────────────────────────────────────────────────
# Baseline — management account roots the org-level controls.
#
# This file wires member-account providers and invokes the per-account
# baseline module. The org-level controls (CloudTrail, Config, GuardDuty,
# Security Hub delegation) live in the files above and use the `management`
# provider.
#
# Provider aliases are configured per-account via an assume-role chain from
# the opentofu-deploy role in each member account.
# ─────────────────────────────────────────────────────────────────────────────

provider "aws" {
  alias  = "security"
  region = var.region

  # Allow plan-only tests without live credentials.
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true

  # When applying, target the Security account by exporting the matching
  # profile / role via the standard env vars (AWS_ACCESS_KEY_ID, AWS_PROFILE)
  # or session. This avoids hardcoding a cross-account role chain and keeps
  # the offline plan tests free of STS round-trips.
}

# The deploy role is created in the management account itself (the baseline
# runs here). Member-account deploy roles are created by the deploy-role
# terraservice in each environment, using this module as the source.
module "deploy_role_management" {
  source = "../../modules/aws/deploy-role"
  count  = var.cicd_oidc_provider_arn != null ? 1 : 0

  role_name                = var.cicd_role_name
  oidc_provider_arn        = var.cicd_oidc_provider_arn
  allowed_subjects         = ["repo:*:*:ref:refs/heads/main"]
  permissions_boundary_arn = null

  tags = merge(var.default_tags, { Name = "opentofu-deploy" })
}