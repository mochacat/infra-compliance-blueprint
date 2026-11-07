# Compliance test — validates the module REFUSES non-compliant inputs at
# plan time. These expect_failures are the audit gates (Pillar 1 — Encryption / Pillar 4 — High Availability & Region Control / Pillar 6 — Backup, DR & Deletion Protection / Pillar 7 — Data Residency & Sovereignty).

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

# ── Expect failure: PHI without sovereign_only (Pillar 7 — Data Residency & Sovereignty) ────────────────────
run "fail_phi_not_sovereign" {
  command = plan

  variables {
    environment         = "prod"
    name                = "phi-cluster"
    region              = "us-east-1"
    kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
  secret_arn          = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-db"
    data_classification = "phi"
    data_residency = {
      sovereign_only = false
    }
    network = {
      vpc_id     = "vpc-0a1b2c3d4e5f67890"
      subnet_ids = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
    }
  }

  expect_failures = [
    aws_rds_cluster.this
  ]
}

# ── Expect failure: region not in allowed_regions (Pillar 4 — High Availability & Region Control) ─────────────────
run "fail_unapproved_region" {
  command = plan

  variables {
    environment         = "dev"
    name                = "bad-region-cluster"
    region              = "us-east-2"
    kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
  secret_arn          = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-db"
    data_classification = "internal"
    network = {
      vpc_id     = "vpc-0a1b2c3d4e5f67890"
      subnet_ids = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
    }
  }

  expect_failures = [
    aws_rds_cluster.this
  ]
}

# ── Expect failure: retention below 30 days (Pillar 6 — Backup, DR & Deletion Protection) ──────────────────────
run "fail_short_retention" {
  command = plan

  variables {
    environment         = "dev"
    name                = "short-retention"
    region              = "us-east-1"
    kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
  secret_arn          = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-db"
    data_classification = "internal"
    backup = {
      retention_days = 14
    }
    network = {
      vpc_id     = "vpc-0a1b2c3d4e5f67890"
      subnet_ids = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
    }
  }

  expect_failures = [
    aws_rds_cluster.this
  ]
}

# ── Expect failure: cross-region DR on PHI without sovereign (Pillar 7 — Data Residency & Sovereignty) ─────
run "fail_dr_phi_not_sovereign" {
  command = plan

  variables {
    environment         = "prod"
    name                = "phi-dr-cluster"
    region              = "us-east-1"
    kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
    secret_arn          = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-db"
    data_classification = "phi"
    data_residency = {
      sovereign_only = false
    }
    backup = {
      cross_region_replica = true
      replica_region       = "us-west-2"
    }
    network = {
      vpc_id     = "vpc-0a1b2c3d4e5f67890"
      subnet_ids = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
    }
  }

  expect_failures = [
    aws_rds_global_cluster.this
  ]
}

# ── Expect failure: DR to an unapproved region (Pillar 4 — High Availability & Region Control / Pillar 6 — Backup, DR & Deletion Protection) ─────────────────
run "fail_dr_unapproved_region" {
  command = plan

  variables {
    environment         = "dev"
    name                = "bad-dr-region"
    region              = "us-east-1"
    kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/0a1b2c3d4e5f67890"
    secret_arn          = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-db"
    data_classification = "internal"
    backup = {
      cross_region_replica = true
      replica_region       = "ap-south-1"
    }
    network = {
      vpc_id     = "vpc-0a1b2c3d4e5f67890"
      subnet_ids = ["subnet-0a1b2c3d4e5f67890", "subnet-0a1b2c3d4e5f67891"]
    }
  }

  expect_failures = [
    aws_rds_global_cluster.this
  ]
}