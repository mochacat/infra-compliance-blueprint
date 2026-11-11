# Defaults test — validates the module produces a compliant pgvector cluster
# with tight defaults (KMS encryption, deletion protection, retention ≥ 30,
# RDS Proxy with TLS, serverless in dev).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "dev"
  name                = "sample-pgvector"
  region              = "us-east-1"
  kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
  data_classification = "internal"
  network = {
    vpc_id       = "vpc-0a1b2c3d4e5f67890"
    subnet_ids   = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
    private_only = true
  }
}

run "test_kms_encryption" {
  command = plan

  assert {
    condition     = aws_rds_cluster.this.storage_encrypted == true
    error_message = "Cluster must be encrypted at rest."
  }
  assert {
    condition     = aws_rds_cluster.this.kms_key_id == var.kms_key_arn
    error_message = "Cluster must use the caller-provided KMS key."
  }
}

run "test_deletion_protection_on" {
  command = plan

  assert {
    condition     = aws_rds_cluster.this.deletion_protection == true
    error_message = "Deletion protection must be enabled by default."
  }
}

run "test_retention_30" {
  command = plan

  assert {
    condition     = aws_rds_cluster.this.backup_retention_period >= 30
    error_message = "Backup retention must be at least 30 days (Pillar 6 — Backup, DR & Deletion Protection)."
  }
}

run "test_serverless_in_dev" {
  command = plan

  assert {
    condition     = aws_rds_cluster.this.engine_mode == "serverless"
    error_message = "Dev should use serverless engine mode for cost (Pillar 10 — FinOps & Cost Controls)."
  }
  assert {
    condition     = output.compliance_controls.engine_mode == "serverless"
    error_message = "compliance_controls must report serverless engine mode."
  }
}

run "test_proxy_tls" {
  command = plan

  assert {
    condition     = aws_db_proxy.this.require_tls == true
    error_message = "RDS Proxy must require TLS."
  }
  assert {
    condition     = output.compliance_controls.proxy_enabled == true
    error_message = "RDS Proxy must be reported as enabled."
  }
}

run "test_compliance_controls" {
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
    condition     = output.compliance_controls.multi_az == true
    error_message = "multi_az must be true (Aurora is multi-AZ)."
  }
  assert {
    condition     = output.compliance_controls.private_network == true
    error_message = "private_network must be true."
  }
  assert {
    condition     = output.compliance_controls.proxy_enabled == true
    error_message = "proxy_enabled must be true."
  }
  assert {
    condition     = output.compliance_controls.require_tls == true
    error_message = "require_tls must be true."
  }
}

# ── Cross-region DR (Pillar 6 — Backup, DR & Deletion Protection) — opt-in global cluster ───────────────────────
run "test_cross_region_dr" {
  command = plan

  variables {
    backup = {
      retention_days       = 35
      cross_region_replica = true
      replica_region       = "us-west-2"
    }
  }

  assert {
    condition     = aws_rds_global_cluster.this[0].global_cluster_identifier == "${var.name}-pgvector-global"
    error_message = "Global cluster must be created when cross_region_replica is enabled."
  }
  assert {
    condition     = aws_rds_global_cluster.this[0].deletion_protection == true
    error_message = "DR global cluster must have deletion protection on."
  }
  assert {
    condition     = output.compliance_controls.cross_region_dr_enabled == true
    error_message = "compliance_controls must report DR enabled."
  }
  assert {
    condition     = output.compliance_controls.dr_replica_region == "us-west-2"
    error_message = "compliance_controls must report the replica region."
  }
}

run "test_no_dr_by_default" {
  command = plan

  assert {
    condition     = length(aws_rds_global_cluster.this) == 0
    error_message = "Cross-region DR must be opt-in; no global cluster by default."
  }
}

run "test_manage_master_password" {
  command = plan

  assert {
    condition     = aws_rds_cluster.this.manage_master_user_password == true
    error_message = "RDS must manage the master user password (manage_master_user_password = true)."
  }
  assert {
    condition     = aws_rds_cluster.this.master_user_secret_kms_key_id == var.kms_key_arn
    error_message = "Master user secret must be encrypted with the caller-provided KMS key."
  }
}