# development/platform/iam — default plan test
# Verifies the IAM layer plans successfully with dev defaults.

run "plan_defaults" {
  command = plan

  variables {
    environment        = "dev"
    region             = "us-east-1"
    data_classification = "internal"
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
    condition     = can(regex("arn:aws:iam::", output.ecs_task_exec_role_arn))
    error_message = "Must produce an ECS task execution role ARN"
  }
}
