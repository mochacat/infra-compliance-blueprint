# ─────────────────────────────────────────────────────────────────────────────
# Plan-time tests for the bootstrap terraservice.
#
# These run against the AWS provider's plan — no credentials required, no
# real resources created. They validate that the org structure and SCP set are
# wired correctly.
# ─────────────────────────────────────────────────────────────────────────────

variables {
  org_email            = "root@example.com"
  account_email_domain = "example.com"
}

run "test_organization_config" {
  command = plan

  assert {
    condition     = aws_organizations_organization.this.feature_set == "ALL"
    error_message = "Organization must enable all features for SCPs to work."
  }

  assert {
    condition     = contains(aws_organizations_organization.this.aws_service_access_principals, "cloudtrail.amazonaws.com")
    error_message = "CloudTrail must be enabled as an org service principal."
  }

  assert {
    condition     = contains(aws_organizations_organization.this.aws_service_access_principals, "guardduty.amazonaws.com")
    error_message = "GuardDuty must be enabled as an org service principal."
  }
}

run "test_ou_structure" {
  command = plan

  assert {
    condition     = aws_organizations_organizational_unit.infra_control_plane.name == "Infra-Control-Plane"
    error_message = "Infra-Control-Plane OU must be created."
  }

  assert {
    condition     = aws_organizations_organizational_unit.infra_control_plane_network.name == "Network"
    error_message = "Network OU must be nested under Infra-Control-Plane."
  }

  assert {
    condition     = aws_organizations_organizational_unit.production.name == "Production"
    error_message = "Production OU must be created."
  }

  assert {
    condition = length([
      aws_organizations_organizational_unit.prod_platform,
      aws_organizations_organizational_unit.prod_research,
      aws_organizations_organizational_unit.prod_data,
    ]) == 3
    error_message = "Production must have Platform, Research, and DataPlatform child OUs."
  }

  assert {
    condition     = aws_organizations_organizational_unit.sandbox.name == "Sandbox"
    error_message = "Sandbox OU must be created."
  }
}

run "test_root_scps" {
  command = plan

  assert {
    condition     = aws_organizations_policy.deny_root_user_actions.content != ""
    error_message = "DenyRootUserActions policy must have content."
  }

  assert {
    condition     = aws_organizations_policy.deny_root_user_actions.type == "SERVICE_CONTROL_POLICY"
    error_message = "Must be a Service Control Policy."
  }

  assert {
    condition     = aws_organizations_policy.restrict_regions.content != ""
    error_message = "RestrictRegions policy must have content."
  }

  assert {
    condition     = aws_organizations_policy.enforce_encryption.content != ""
    error_message = "EnforceEncryptionAtRest policy must have content."
  }
}

run "test_prod_scps" {
  command = plan

  assert {
    condition     = aws_organizations_policy.deny_public_access.content != ""
    error_message = "DenyPublicAccess policy must have content."
  }

  assert {
    condition     = aws_organizations_policy.enforce_deletion_protection.content != ""
    error_message = "EnforceDeletionProtection policy must have content."
  }

  assert {
    condition     = aws_organizations_policy.deny_snapshot_skip.content != ""
    error_message = "DenySnapshotSkip policy must have content."
  }
}

run "test_scp_count" {
  command = plan

  assert {
    condition = length([
      aws_organizations_policy.deny_root_user_actions,
      aws_organizations_policy.restrict_regions,
      aws_organizations_policy.enforce_encryption,
      aws_organizations_policy.deny_cloudtrail_disable,
      aws_organizations_policy.deny_public_access,
      aws_organizations_policy.enforce_deletion_protection,
      aws_organizations_policy.deny_snapshot_skip,
      aws_organizations_policy.protect_log_archive,
      aws_organizations_policy.enforce_tags,
    ]) == 9
    error_message = "Exactly 9 SCPs must be defined."
  }
}
