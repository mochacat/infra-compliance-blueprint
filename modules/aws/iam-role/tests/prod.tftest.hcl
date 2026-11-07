# Production plan test — strictest inputs: permissions boundary required,
# PHI classification with sovereign residency, all tags set.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "prod"
  name                = "prod-app-role"
  data_classification = "phi"
  trust_policy        = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ecs-tasks.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }
  EOF
  policy_statements = [
    {
      sid       = "SecretsManagerRead"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      resources = ["arn:aws:secretsmanager:us-east-1:222222222222:secret:prod-*"]
    }
  ]
  permissions_boundary_arn = "arn:aws:iam::222222222222:policy/prod-boundary"
  managed_policy_arns      = ["arn:aws:iam::222222222222:policy/prod-compliant-base"]
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }
  cost_controls = {
    cost_center  = "ops"
    project_code = "prod-app"
  }
  default_tags = {
    Team = "platform"
  }
}

run "test_prod_role_name" {
  command = plan

  assert {
    condition     = aws_iam_role.this.name == "prod-app-role"
    error_message = "Role name must match input."
  }
}

run "test_prod_permissions_boundary" {
  command = plan

  assert {
    condition     = aws_iam_role.this.permissions_boundary == "arn:aws:iam::222222222222:policy/prod-boundary"
    error_message = "Prod role must have a permissions boundary (Pillar 2 — Access Control & Least Privilege)."
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

run "test_prod_managed_policy_attached" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy_attachment.managed) == 1
    error_message = "One managed policy should be attached in prod."
  }
}

run "test_phi_sovereign_residency" {
  command = plan

  assert {
    condition     = aws_iam_role.this.tags["DataClassification"] == "phi"
    error_message = "PHI classification must be reflected in tags."
  }
}