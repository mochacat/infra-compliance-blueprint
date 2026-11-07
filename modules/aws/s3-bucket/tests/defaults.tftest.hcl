# Defaults test — a plain data bucket with the compliance posture locked on.

provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variables {
  environment         = "dev"
  region              = "us-east-1"
  name                = "demo-s3-bucket"
  kms_key_arn         = "arn:aws:kms:us-east-1:111111111111:key/aaaa-bbbb-cccc-dddd"
  data_classification = "internal"
  data_residency      = {}
  cost_controls       = { cost_center = "sec", project_code = "demo" }
}

run "test_encryption_cmk" {
  command = plan

  assert {
    condition     = anytrue([for r in aws_s3_bucket_server_side_encryption_configuration.this.rule : r.apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"])
    error_message = "Bucket must use KMS (CMK) encryption, never SSE-S3 (Pillar 1 — Encryption)."
  }
  assert {
    condition     = anytrue([for r in aws_s3_bucket_server_side_encryption_configuration.this.rule : r.apply_server_side_encryption_by_default[0].kms_master_key_id == var.kms_key_arn])
    error_message = "Bucket must use the caller-provided CMK."
  }
}

run "test_public_access_firewalled" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls == true
    error_message = "Public ACLs must be blocked (Pillar 3 — Network Security & Isolation)."
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_policy == true
    error_message = "Public bucket policy must be blocked (Pillar 3 — Network Security & Isolation)."
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.this.restrict_public_buckets == true
    error_message = "Public bucket restriction must be on (Pillar 3 — Network Security & Isolation)."
  }
}

run "test_secure_transport" {
  command = plan

  # SecureTransport is enforced in `data.aws_iam_policy_document.bucket_policy`
  # (main.tf) with a Deny on aws:SecureTransport=false. The fully rendered JSON
  # embeds the bucket ARN, which is unknown at plan time, so we can't string-match
  # it offline. Here we assert the policy is attached; the deny content is caught
  # by Checkov (CKV_AWS_145) and OPA at plan time.
  assert {
    condition     = length(aws_s3_bucket_policy.this) > 0
    error_message = "The bucket must have a policy (SecureTransport deny) attached."
  }
}

run "test_versioning_on" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be enabled by default (Pillar 6 — Backup, DR & Deletion Protection)."
  }
}

run "test_not_audit_bucket_no_object_lock" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_object_lock_configuration.this) == 0
    error_message = "A non-audit bucket must not have Object Lock."
  }
}