# production/platform/ai — default plan test

run "plan_defaults" {
  command = plan

  variables {
    business_unit                 = "platform"
    environment                   = "prod"
    region                        = "us-east-1"
    kms_key_arn                   = "arn:aws:kms:us-east-1:123456789012:key/mock-0000-0000-0000-000000000000"
    vpc_id                        = "vpc-00000000"
    app_subnet_ids                = ["subnet-0001", "subnet-0002"]
    default_security_group_id     = "sg-00000000"
    sagemaker_execution_role_arn  = "arn:aws:iam::123456789012:role/app-sagemaker-exec"
    sagemaker_execution_role_name = "app-sagemaker-exec"
    data_classification           = "internal"
  }

  assert {
    condition     = can(regex("^domain-", output.sagemaker_domain_id))
    error_message = "Must produce a SageMaker domain ID"
  }
}
