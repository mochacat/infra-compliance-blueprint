# aws/s3-bucket

Creates a compliant-by-default S3 bucket for AI/regulated workloads (HIPAA / SOC 2).
Encryption is always a caller-provided CMK, access is TLS-only and never public,
versioning is on, and audit buckets get immutable **Object Lock** with 7-year retention.

## Compliance posture

This module is **compliant by default** and refuses (at `tofu plan`) inputs that
would break that posture:

| Control | Setting | How it's enforced | Pillar |
|---|---|---|---|
| Encryption at rest | `kms_master_key_id = var.kms_key_arn`, `sse_algorithm = "aws:kms"` | caller-provided CMK only; **no SSE-S3, no off toggle** | 1 |
| Encryption in transit | `EnforceSecureTransport` **Deny** on `aws:SecureTransport=false` | bucket policy | 1 |
| Public access | `block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets` all `true` | S3 Block Public Access | 3 |
| Data integrity / DR | versioning `Enabled` by default | `aws_s3_bucket_versioning` | 6 |
| Deletion protection | `force_destroy = false`; audit buckets never scriptable-destroy | hard-coded + `compliance_controls` output | 6 |
| Region control | `region` must be in `allowed_regions` (approved list) | plan-time `precondition`, `Region` tag | 4 |
| Data residency | `phi` demands `sovereign_only = true` | plan-time `precondition` | 7 |
| Audit immutability | Object Lock **COMPLIANCE**, `audit_retention_days >= 2557` (7 yr) on `audit_bucket = true` | `aws_s3_bucket_object_lock_configuration` + validation | 8 |
| Observable logs | access logs shipped to a centralized bucket | `observability.log_bucket_id` | 5 |
| FinOps tags | `CostCenter`, `Project`, `Environment`, `DataClassification`, `Jurisdiction` | base tags | 10 |

## Usage

```hcl
module "app_bucket" {
  source = "git::https://github.com/anestoa/infrastructure.git//modules/aws/s3-bucket?ref=v1.0.0"

  environment         = "prod"
  name                = "anestoa-app-data-prod"
  kms_key_arn         = module.app_key.key_arn      # Pillar 1 — Encryption (caller-provided CMK)
  data_classification = "phi"
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }
  observability = {
    log_bucket_id = module.audit_bucket.bucket_id   # Pillar 5 — Observability (centralized logs)
  }
  cost_controls = {
    cost_center  = "ops"
    project_code = "app"
  }
}
```

An **audit bucket** (immutable, 7-year, COMPLIANCE Object Lock):

```hcl
module "audit_bucket" {
  source = "git::.../s3-bucket?ref=v1.0.0"

  environment         = "prod"
  name                = "anestoa-audit-prod"
  kms_key_arn         = module.audit_key.key_arn
  audit_bucket        = true
  audit_lock_mode     = "COMPLIANCE"     # GOVERNANCE disallowed in prod by OPA
  audit_retention_days = 2557            # 7 years, enforced >= 2557
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `environment` | string | *(required)* | dev/test/staging/prod/commercial. |
| `region` | string | *(required)* | Target region; must be in `allowed_regions` (Pillar 4 — High Availability & Region Control). |
| `allowed_regions` | list(string) | `["us-east-1","us-west-2","eu-west-1","eu-central-1"]` | Approved regions for bucket placement. |
| `name` | string | *(required)* | Globally unique bucket name. |
| `kms_key_arn` | string | *(required)* | CMK ARN for encryption at rest. Module does **not** create a key. |
| `audit_bucket` | bool | `false` | Enable Object Lock for audit/evidence storage. |
| `audit_lock_mode` | string | `"COMPLIANCE"` | COMPLIANCE or GOVERNANCE (Both validated). |
| `audit_retention_days` | number | `2557` | Object Lock retention; enforced `>= 2557` (7 yr). |
| `versioning_enabled` | bool | `true` | Enable S3 versioning. |
| `data_classification` | string | `"internal"` | internal/pii/phi/financial/cardholder. |
| `data_residency` | object | `{}` | `sovereign_only`, `jurisdiction`, etc. |
| `observability` | object | `{}` | `log_bucket_id` (name/id, not ARN), `log_prefix`, `alarm_topic_arn`. |
| `cost_controls` | object | `{}` | `cost_center`, `project_code`. |
| `default_tags` | map(string) | `{}` | Extra base tags. |

## Outputs

| Name | Description |
|---|---|
| `bucket_id` | Bucket name (`id`). |
| `bucket_arn` | Bucket ARN. |
| `bucket_domain_name` | Regional domain name. |
| `compliance_controls` | Machine-readable compliance state for OPA / drift checks. |

## Testing

```sh
tofu test tests/
#  12 assertions across defaults, audit, and compliance-failure scenarios
```

## Checks

- `tofu validate` : valid
- `tofu test`     : 12/12 passing
- Checkov         : run `checkov --framework terraform -d .` (false positives on the
  SecureTransport deny policy are documented via `checkov:skip` if flagged)

## Related

- [`../kms-key`](../kms-key) — produces the `kms_key_arn` this module consumes (Pillar 1 — Encryption).
- `landing-zone/baseline/audit-bucket.tf` — the shared log-archive bucket that uses this
  posture (Object Lock COMPLIANCE, 7-year).