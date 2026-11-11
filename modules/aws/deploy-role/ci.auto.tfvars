role_name         = "opentofu-deploy"
oidc_provider_arn = "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com"
allowed_subjects  = ["repo:org/repo:ref:refs/heads/main"]
tags = {
  ManagedBy   = "tofu"
  Environment = "dev"
}
allowed_regions    = ["us-east-1", "us-west-2"]
data_classification = "internal"
default_tags       = {}
