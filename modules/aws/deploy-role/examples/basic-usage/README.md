# deploy-role example

Creates an `opentofu-deploy` CI/CD role that Atlantis assumes via GitHub OIDC.

## Usage

```hcl
module "deploy_role" {
  source = "../../"

  role_name              = "opentofu-deploy"
  oidc_provider_arn      = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  allowed_subjects       = ["repo:anestoa/infrastructure:ref:refs/heads/main"]
  permissions_boundary_arn = "arn:aws:iam::123456789012:policy/cicd-boundary"

  tags = {
    ManagedBy   = "tofu"
    Environment = "prod"
    CostCenter  = "infra"
    Project     = "anestoa"
  }
}
```

Replace the account ID and OIDC provider ARN with your real values.