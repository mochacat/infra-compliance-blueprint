# Defaults test — validates the module produces a Fargate-first, private,
# observability-backed ECS cluster with compliant defaults.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "dev"
  name                = "sample-ecs"
  region              = "us-east-1"
  kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
  data_classification = "internal"
  network = {
    vpc_id             = "vpc-0a1b2c3d4e5f67890"
    subnet_ids         = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
    security_group_ids = ["sg-0a1b2c3d4e5f67890"]
  }
}

run "test_cluster_exists" {
  command = plan

  variables {
    name = "sample-ecs"
  }

  assert {
    condition     = aws_ecs_cluster.this.name == "sample-ecs"
    error_message = "Cluster name must match var.name."
  }
}

run "test_fargate_default" {
  command = plan

  assert {
    condition     = contains(aws_ecs_cluster_capacity_providers.this.capacity_providers, "FARGATE")
    error_message = "FARGATE must be a default capacity provider."
  }
}

run "test_log_group_encrypted" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.tasks.kms_key_id == var.kms_key_arn
    error_message = "Task log group must be encrypted with the caller-provided CMK (Pillar 1)."
  }
}

run "test_log_group_retention" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.tasks.retention_in_days >= 30
    error_message = "Task log retention must be at least 30 days (Pillar 6)."
  }
}

run "test_default_no_alarms_without_topic" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.cpu_reservation) == 0
    error_message = "No alarms expected when alarm_topic_arn is not set."
  }
}

run "test_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.encryption_at_rest == true
    error_message = "compliance_controls must report encryption_at_rest."
  }
  assert {
    condition     = output.compliance_controls.fargate_first == true
    error_message = "compliance_controls must report fargate_first."
  }
}