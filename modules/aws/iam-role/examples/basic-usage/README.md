# iam-role example

Creates a scoped IAM role for an ECS task with S3 read access.

## Usage

```hcl
module "app_role" {
  source = "../../"

  environment         = "dev"
  name                = "app-role"
  data_classification = "internal"

  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  policy_statements = [
    {
      sid       = "S3Read"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:ListBucket"]
      resources = ["arn:aws:s3:::app-data-bucket", "arn:aws:s3:::app-data-bucket/*"]
    }
  ]

  permissions_boundary_arn = "arn:aws:iam::123456789012:policy/app-boundary"
  max_session_duration     = 43200

  cost_controls = {
    cost_center  = "engineering"
    project_code = "app"
  }

  default_tags = {
    Team = "platform"
  }
}
```

Replace the account ID and boundary ARN with your real values.