# development/research/network — default plan test

run "plan_defaults" {
  command = plan

  variables {
    environment        = "dev"
    region             = "us-east-1"
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
