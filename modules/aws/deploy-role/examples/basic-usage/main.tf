# ─────────────────────────────────────────────────────────────────────────────
# Example: deploy-role module
#
# Creates the opentofu-deploy CI/CD role for a single AWS account. This role
# is assumed by Atlantis (via GitHub OIDC) to run plans and applies.
# ─────────────────────────────────────────────────────────────────────────────

module "deploy_role" {
  source = "../../"

  role_name                = "opentofu-deploy"
  oidc_provider_arn        = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  allowed_subjects         = ["repo:anestoa/infrastructure:ref:refs/heads/main"]
  permissions_boundary_arn = "arn:aws:iam::123456789012:policy/cicd-boundary"

  tags = {
    ManagedBy   = "tofu"
    Environment = "prod"
    CostCenter  = "infra"
    Project     = "anestoa"
  }
}