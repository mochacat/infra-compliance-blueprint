# Prod test — validates prod-grade posture: encrypted logs, retention,
# compliance_controls output reflects the PHI classification.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "prod"
  name                = "prod-ecs"
  region              = "us-east-1"
  kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
  data_classification = "phi"
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }
  network = {
    vpc_id             = "vpc-0a1b2c3d4e5f67890"
    subnet_ids         = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
    security_group_ids = ["sg-0a1b2c3d4e5f67890"]
  }
  observability = {
    alarm_topic_arn    = "arn:aws:sns:us-east-1:123456789012:alarms"
    log_retention_days = 365
  }
  backup = {
    log_retention_days = 365
  }
}

run "test_prod_tags" {
  command = plan

  assert {
    condition     = aws_ecs_cluster.this.tags.Environment == "prod"
    error_message = "Cluster must be tagged with the environment."
  }
}

run "test_prod_log_encrypted" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.tasks.kms_key_id == var.kms_key_arn
    error_message = "Prod task log group must be encrypted with the CMK."
  }
}

run "test_prod_log_retention" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.tasks.retention_in_days >= 365
    error_message = "Prod log retention must be at least 365 days."
  }
}

run "test_prod_alarms" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.cpu_reservation) == 1
    error_message = "Prod must create the CPU reservation alarm when a topic is set."
  }
  assert {
    condition     = length(aws_cloudwatch_metric_alarm.memory_reservation) == 1
    error_message = "Prod must create the memory reservation alarm when a topic is set."
  }
}

run "test_prod_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.data_classification == "phi"
    error_message = "compliance_controls must report the PHI classification."
  }
}