# Prod test — validates the module produces a production-grade pgvector cluster
# (provisioned engine, prod retention, deletion protection, PHI-sovereign,
# monitoring on, full observability).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "prod"
  name                = "prod-core-pgvector"
  region              = "us-east-1"
  kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
  secret_arn          = "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod-core-db"
  master_username     = "appadmin"
  master_password     = "supersecret-password-from-secretsmanager"
  data_classification = "phi"
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }
  high_availability = {
    replica_count = 2
  }
  backup = {
    retention_days      = 35
    deletion_protection = true
    skip_final_snapshot = false
  }
  network = {
    vpc_id       = "vpc-0a1b2c3d4e5f67890"
    subnet_ids   = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891", "subnet-0a1b2c3d4e5f67892"]
    private_only = true
    allowed_cidrs = ["10.0.0.0/16"]
  }
  observability = {
    log_group_name      = "prod-core-pgvector"
    log_retention_days  = 90
    alarm_topic_arn     = "arn:aws:sns:us-east-1:123456789012:prod-alarms"
    detailed_monitoring = true
  }
  cost_controls = {
    instance_class = "db.r7g.large"
    cost_center    = "platform"
    project_code   = "core"
  }
}

run "test_prod_provisioned" {
  command = plan

  assert {
    condition     = aws_rds_cluster.this.engine_mode == "provisioned"
    error_message = "Prod should use provisioned engine mode."
  }
  assert {
    condition     = aws_rds_cluster.this.backup_retention_period >= 30
    error_message = "Prod retention must be at least 30 days."
  }
  assert {
    condition     = aws_rds_cluster.this.deletion_protection == true
    error_message = "Prod must have deletion protection enabled."
  }
  assert {
    condition     = aws_rds_cluster.this.skip_final_snapshot == false
    error_message = "Prod must not skip the final snapshot."
  }
}

run "test_prod_ha" {
  command = plan

  assert {
    condition     = length(aws_rds_cluster_instance.this) >= 2
    error_message = "Prod should have ≥ 2 cluster instances (Pillar 4 — High Availability & Region Control)."
  }
}

run "test_prod_monitoring" {
  command = plan

  assert {
    condition     = aws_rds_cluster_instance.this[0].monitoring_interval == 60
    error_message = "Enhanced monitoring must be on in prod."
  }
  assert {
    condition     = aws_rds_cluster_instance.this[0].performance_insights_enabled == true
    error_message = "Performance Insights must be enabled."
  }
}

run "test_prod_tags" {
  command = plan

  assert {
    condition     = aws_rds_cluster.this.tags["Environment"] == "prod"
    error_message = "Environment tag must be prod."
  }
  assert {
    condition     = aws_rds_cluster.this.tags["CostCenter"] == "platform"
    error_message = "CostCenter tag must be set."
  }
  assert {
    condition     = aws_rds_cluster.this.tags["DataClassification"] == "phi"
    error_message = "DataClassification tag must be phi."
  }
}

run "test_prod_compliance_controls" {
  command = plan

  assert {
    condition     = output.compliance_controls.encryption_at_rest == true
    error_message = "encryption_at_rest must be true."
  }
  assert {
    condition     = output.compliance_controls.deletion_protection == true
    error_message = "deletion_protection must be true."
  }
  assert {
    condition     = output.compliance_controls.engine_mode == "provisioned"
    error_message = "engine_mode must be provisioned."
  }
}