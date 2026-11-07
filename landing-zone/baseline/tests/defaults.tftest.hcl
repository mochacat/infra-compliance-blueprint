# Plan-time tests for the baseline terraservice.
# Uses plan (no apply, no credentials) — validates the compliance controls.

variables {
  management_account_id  = "111111111111"
  log_archive_account_id = "222222222222"
  security_account_id    = "333333333333"
  environment            = "prod"
}

run "test_audit_bucket_compliance" {
  command = plan

  # Object Lock in COMPLIANCE mode with 7-year retention.
  assert {
    condition     = anytrue(flatten([for c in aws_s3_bucket_object_lock_configuration.audit : [for r in c.rule : r.default_retention[0].mode == "COMPLIANCE"]]))
    error_message = "Audit bucket must use Object Lock COMPLIANCE mode (HIPAA 164.312(c)(2))."
  }
  assert {
    condition     = anytrue(flatten([for c in aws_s3_bucket_object_lock_configuration.audit : [for r in c.rule : r.default_retention[0].days >= 2557]]))
    error_message = "Audit retention must be at least 2557 days (7 years)."
  }

  # Versioning on.
  assert {
    condition     = anytrue([for v in aws_s3_bucket_versioning.audit : v.versioning_configuration[0].status == "Enabled"])
    error_message = "Audit bucket must have versioning enabled (SOC 2 CC7.1)."
  }

  # KMS encryption at rest.
  assert {
    condition     = anytrue(flatten([for s in aws_s3_bucket_server_side_encryption_configuration.audit : [for r in s.rule : r.apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"]]))
    error_message = "Audit bucket must use KMS encryption (Pillar 1 — Encryption)."
  }

  # KMS key has rotation enabled.
  assert {
    condition     = anytrue([for k in aws_kms_key.audit : k.enable_key_rotation == true])
    error_message = "Audit KMS key must have rotation enabled."
  }
}

run "test_audit_bucket_public_access_blocked" {
  command = plan

  assert {
    condition     = anytrue([for b in aws_s3_bucket_public_access_block.audit : b.block_public_acls && b.block_public_policy && b.restrict_public_buckets && b.ignore_public_acls])
    error_message = "All public access block flags must be set on the audit bucket."
  }
}

run "test_cloudtrail_enforced" {
  command = plan

  assert {
    condition     = anytrue([for t in aws_cloudtrail.org : t.enable_log_file_validation])
    error_message = "CloudTrail must validate log file integrity (HIPAA 164.312(b))."
  }
  assert {
    condition     = anytrue([for t in aws_cloudtrail.org : t.is_multi_region_trail])
    error_message = "CloudTrail must be multi-region."
  }
  assert {
    condition     = anytrue([for t in aws_cloudtrail.org : t.is_organization_trail])
    error_message = "CloudTrail must be an organization trail."
  }
  assert {
    condition     = anytrue([for t in aws_cloudtrail.org : contains(t.event_selector[*].read_write_type, "All")])
    error_message = "CloudTrail must capture both read and write events."
  }
}

run "test_baseline_skips_when_accounts_null" {
  command = plan
  variables {
    log_archive_account_id = null
    security_account_id    = null
  }

  assert {
    condition     = length(aws_s3_bucket.audit) == 0
    error_message = "Audit bucket must be skipped when log_archive_account_id is null."
  }
  assert {
    condition     = length(aws_cloudtrail.org) == 0
    error_message = "CloudTrail must be skipped when log_archive_account_id is null."
  }
  assert {
    condition     = length(aws_guardduty_detector.org) == 0
    error_message = "GuardDuty must be skipped when security_account_id is null."
  }
}