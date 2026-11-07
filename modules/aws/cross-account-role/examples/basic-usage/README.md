# cross-account-role example

Creates a role in this account that a specific role in another account can
assume to read from a shared S3 bucket. Trust is pinned to explicit source
account ARNs (no wildcards), with an ExternalId condition.

## Usage

```hcl
module "shared_log_reader" {
  source = "../../"

  environment = "dev"
  name        = "log-reader"

  source_account_arns = [
    "arn:aws:iam::111111111111:role/SecurityAudit",
  ]

  trust_conditions = {
    test     = "StringEquals"
    variable = "sts:ExternalId"
    values   = ["audit-external-id"]
  }

  policy_statements = [
    {
      sid       = "ReadLogArchive"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:ListBucket"]
      resources = ["arn:aws:s3:::log-archive", "arn:aws:s3:::log-archive/*"]
    }
  ]

  permissions_boundary_arn = "arn:aws:iam::222222222222:policy/cross-account-boundary"

  cost_controls = {
    cost_center  = "security"
    project_code = "audit"
  }

  default_tags = {
    Team = "platform"
  }
}
```

Replace the account IDs and boundary ARN with your real values.