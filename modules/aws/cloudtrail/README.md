# cloudtrail

> Infra-team-owned, org-wide CloudTrail audit trail — compliant by default.
> Deployed in the Log Archive / delegated-admin account as the immutable source
> of truth for every API call across the organization.

This is a reusable **building block**, distinct from the one-off
`landing-zone/baseline/cloudtrail.tf` terraservice. It can be composed into any
terraservice (including a future `baseline/` refactor) or consumed directly by a
single account.

## What it creates

| Resource | Purpose |
|---|---|
| `aws_cloudtrail` | Multi-region, org-wide trail, log-file validation on |
| `aws_s3_bucket` | Immutable audit log bucket (Object Lock, versioning, KMS) |
| `aws_s3_bucket_object_lock_configuration` | COMPLIANCE lock, 7-year retention |
| `aws_s3_bucket_policy` | SecureTransport-only + CloudTrail delivery |
| `aws_s3_bucket_public_access_block` | Public access blocked at every layer |
| `aws_cloudwatch_log_group` | Trail streaming destination (KMS-encrypted) |
| `aws_iam_role` | CloudTrail → CloudWatch logs role (least-privilege) |
| `aws_cloudwatch_metric_alarm` | In-default: alarms `alarm_topic_arn` if ingestion stops |

## Compliance posture

| Pillar | Control | Enforced by |
|---|---|---|
| 1 — Encryption | KMS CMK for bucket + log group (never AWS-owned, no toggle) | Module default + OPA |
| 3 — Network | Public access blocked, TLS-only bucket policy | Module default + OPA |
| 5 — Observability | CloudWatch streaming + ingestion alarm | Module default |
| 6 — Backup/DR | Versioning always on, `prevent_destroy`, retention ≥ 30 | Module default |
| 7 — Residency | PHI-sovereign gate on audit data | Lifecycle precondition |
| 8 — Audit | Object Lock COMPLIANCE, 7-yr retention, log-file validation | Module default + OPA |
| 10 — FinOps | `CostCenter` / `Project` tags | Module default + OPA |

## Usage

```hcl
module "org_trail" {
  source = "git::https://example.com/infra.git//modules/aws/cloudtrail?ref=v1.0.0"

  environment = "prod"
  name        = "anestoa-org"
  region      = "us-east-1"
  kms_key_arn = module.audit_kms.arn   # from the kms-key module

  # Org-wide trail streaming to CloudWatch; alarm if ingestion stops
  observability = {
    log_retention_days = 365
    alarm_topic_arn    = module.security_ops.alarm_topic_arn
  }

  # PHI audit data → sovereign-only, no cross-border
  data_classification = "phi"
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }

  default_tags = {
    CostCenter = "security"
    Project    = "platform"
  }
}
```

> The audit KMS key is **not** created here — provision it with the `kms-key`
> module and pass its ARN. This keeps the audit trail auditable (key lifecycle
> and trail lifecycle are independently manageable).

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| `environment` | dev/test/staging/prod/commercial | — | yes |
| `name` | Trail name prefix (→ `<name>-trail`) | — | yes |
| `region` | Home region (approved) | — | yes |
| `allowed_regions` | Approved regions | `us-east-1`… | no |
| `kms_key_arn` | CMK for bucket + log group | — | yes |
| `is_organization_trail` | Org-wide trail | `true` | no |
| `bucket_name_prefix` | Audit bucket name | `var.name` | no |
| `data_events` | S3/Lambda data event selectors | empty (mgmt only) | no |
| `cloudtrail_insights` | Insights event selector | `null` | no |
| `observability.log_retention_days` | CloudWatch retention | `90` | no |
| `observability.alarm_topic_arn` | Ingestion alarm topic | `null` | no |
| `backup` | retention / prevent_destroy | `{}` | no |
| `data_classification` | internal/pii/phi/... | `internal` | no |
| `data_residency` | sovereign / jurisdiction | `{}` | no |
| `audit_lock_mode` | COMPLIANCE/GOVERNANCE | `COMPLIANCE` | no |
| `audit_retention_days` | Object Lock retention | `2557` | no |
| `iam.cloudwatch_logs_role_name_prefix` | Role name prefix | `""` | no |
| `default_tags` | Base tags | `{}` | no |

## Outputs

`trail_arn`, `trail_home_region`, `trail_s3_bucket_arn`, `trail_s3_bucket_id`,
`log_group_arn`, `log_group_name`, `cloudwatch_role_arn`, `compliance_controls`.

## Enforcement

- **`tofu test tests/`** — asserts multi-region, log-file validation, KMS
  encryption, Object Lock, versioning, and refuses an unapproved region, PHI
  without sovereignty, and short retention.
- **`policies/cloudtrail.rego`** — OPA denies a non-multi-region trail, missing
  log-file validation, non-KMS bucket, missing `CostCenter`, and a bucket policy
  without `SecureTransport`. Run at plan time (Atlantis/CI).
- **Checkov** — passes without skips on the defaults.