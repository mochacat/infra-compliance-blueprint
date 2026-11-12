# Offline provider — plan-only test; no real AWS credentials required.
provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

# production/data-platform/iam — default plan test
# Verifies the IAM layer plans successfully with dev defaults.

run "plan_defaults" {
  command = plan

  variables {
    business_unit            = "data-platform"
    environment              = "prod"
    permissions_boundary_arn = "arn:aws:iam::123456789012:policy/ci-boundary"
    region                   = "us-east-1"
    data_classification      = "internal"
    cost_controls = {
      cost_center  = "engineering"
      project_code = "anestoa"
    }
    app_name = "app"
  }

  assert {
    condition     = can(regex("^arn:aws:kms:", output.app_kms_key_arn))
    error_message = "Must produce a valid KMS key ARN"
  }

  assert {
    condition     = output.ecs_task_exec_role_name == "prod-app-ecs-task-exec"
    error_message = "Must produce the expected ECS task execution role name"
  }
}
