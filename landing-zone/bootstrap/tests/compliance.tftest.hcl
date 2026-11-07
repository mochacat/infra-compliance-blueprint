# ─────────────────────────────────────────────────────────────────────────────
# Compliance gate tests.
#
# These assert that the SCPs block the actions HIPAA / SOC 2 require. They
# inspect the policy JSON content — no AWS calls, no credentials needed.
# ─────────────────────────────────────────────────────────────────────────────

variables {
  org_email            = "root@example.com"
  account_email_domain = "example.com"
}

run "test_deny_root_user_actions" {
  command = plan

  assert {
    condition     = strcontains(aws_organizations_policy.deny_root_user_actions.content, "arn:aws:iam::*:root")
    error_message = "DenyRootUserActions must match root principal ARNs (HIPAA 164.312(a)(1))."
  }

  assert {
    condition     = strcontains(aws_organizations_policy.deny_root_user_actions.content, "\"Deny\"")
    error_message = "DenyRootUserActions must use Effect Deny."
  }
}

run "test_restrict_regions" {
  command = plan

  assert {
    condition     = strcontains(aws_organizations_policy.restrict_regions.content, "RequestedRegion")
    error_message = "RestrictRegions must condition on aws:RequestedRegion (HIPAA 164.314(a)(1))."
  }

  assert {
    condition     = strcontains(aws_organizations_policy.restrict_regions.content, "StringNotEquals")
    error_message = "RestrictRegions must use StringNotEquals to block non-approved regions."
  }
}

run "test_enforce_encryption_all_services" {
  command = plan

  assert {
    condition     = strcontains(aws_organizations_policy.enforce_encryption.content, "s3:CreateBucket")
    error_message = "Must deny unencrypted S3 bucket creation."
  }

  assert {
    condition     = strcontains(aws_organizations_policy.enforce_encryption.content, "ec2:CreateVolume")
    error_message = "Must deny unencrypted EBS."
  }

  assert {
    condition     = strcontains(aws_organizations_policy.enforce_encryption.content, "rds:CreateDBInstance")
    error_message = "Must deny unencrypted RDS."
  }

  assert {
    condition     = strcontains(aws_organizations_policy.enforce_encryption.content, "elasticfilesystem:CreateFileSystem")
    error_message = "Must deny unencrypted EFS."
  }
}

run "test_deny_cloudtrail_disable" {
  command = plan

  assert {
    condition     = strcontains(aws_organizations_policy.deny_cloudtrail_disable.content, "cloudtrail:StopLogging")
    error_message = "Must deny CloudTrail StopLogging (HIPAA 164.312(b))."
  }

  assert {
    condition     = strcontains(aws_organizations_policy.deny_cloudtrail_disable.content, "cloudtrail:DeleteTrail")
    error_message = "Must deny CloudTrail DeleteTrail."
  }
}

run "test_deny_public_access" {
  command = plan

  assert {
    condition     = strcontains(aws_organizations_policy.deny_public_access.content, "0.0.0.0/0")
    error_message = "Must deny 0.0.0.0/0 security group ingress."
  }

  assert {
    condition     = strcontains(aws_organizations_policy.deny_public_access.content, "public-read")
    error_message = "Must deny public S3 ACLs."
  }
}

run "test_deletion_protection" {
  command = plan

  assert {
    condition     = strcontains(aws_organizations_policy.enforce_deletion_protection.content, "rds:ModifyDBInstance")
    error_message = "Must block disabling RDS deletion protection."
  }
}

run "test_snapshot_skip" {
  command = plan

  assert {
    condition     = strcontains(aws_organizations_policy.deny_snapshot_skip.content, "SkipFinalSnapshot")
    error_message = "Must deny skip_final_snapshot."
  }
}

run "test_log_archive_protection" {
  command = plan

  assert {
    condition     = strcontains(aws_organizations_policy.protect_log_archive.content, "PutBucketPolicy")
    error_message = "Must block log archive bucket policy changes."
  }

  assert {
    condition     = strcontains(aws_organizations_policy.protect_log_archive.content, "PutObjectRetention")
    error_message = "Must block Object Lock retention changes."
  }
}

run "test_mandatory_tags" {
  command = plan

  assert {
    condition     = strcontains(aws_organizations_policy.enforce_tags.content, "aws:RequestTag/Environment")
    error_message = "EnforceMandatoryTags must require the Environment tag (SOC 2 CC6.1 / HIPAA 164.312(a)(1))."
  }

  assert {
    condition     = strcontains(aws_organizations_policy.enforce_tags.content, "aws:RequestTag/CostCenter")
    error_message = "EnforceMandatoryTags must require the CostCenter tag (Pillar 10 — FinOps & Cost Controls)."
  }

  assert {
    condition     = strcontains(aws_organizations_policy.enforce_tags.content, "aws:RequestTag/DataClassification")
    error_message = "EnforceMandatoryTags must require the DataClassification tag (Pillar 7 — Data Residency & Sovereignty)."
  }

  assert {
    condition     = strcontains(aws_organizations_policy.enforce_tags.content, "aws:RequestTag/ManagedBy")
    error_message = "EnforceMandatoryTags must require the ManagedBy tag."
  }

  assert {
    condition     = strcontains(aws_organizations_policy.enforce_tags.content, "ForAnyValue:Null")
    error_message = "EnforceMandatoryTags must use ForAnyValue:Null to catch any missing mandatory tag."
  }
}
