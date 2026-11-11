# production/research/data — default plan test

run "plan_defaults" {
  command = plan

  variables {
    environment        = "prod"
    region             = "us-east-1"
    kms_key_arn        = "arn:aws:kms:us-east-1:123456789012:key/mock-0000-0000-0000-000000000000"
    vpc_id             = "vpc-00000000"
    data_subnet_ids    = ["subnet-0001", "subnet-0002"]
    default_security_group_id = "sg-00000000"
    data_classification = "internal"
    rds_proxy_role_arn = "arn:aws:iam::123456789012:role/app-rds-proxy"
    secret_arn         = "arn:aws:secretsmanager:us-east-1:123456789012:secret:app-db-abc123"
  }

  assert {
    condition     = can(regex("^arn:aws:rds:", output.pgvector_cluster_arn))
    error_message = "Must produce an RDS cluster ARN"
  }
}
