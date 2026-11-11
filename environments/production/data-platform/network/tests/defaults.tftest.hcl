# production/data-platform/network — default plan test

run "plan_defaults" {
  command = plan

  variables {
    business_unit       = "data-platform"
    kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/mock-0000-0000-0000-000000000000"
    environment         = "prod"
    region              = "us-east-1"
    data_classification = "internal"
  }

  assert {
    condition     = can(regex("^vpc-", output.vpc_id))
    error_message = "Must produce a VPC ID"
  }

  assert {
    condition     = length(output.subnet_ids) >= 4
    error_message = "Must create at least 4 subnets (2 tiers × 2 AZs)"
  }
}
