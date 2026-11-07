# aws/kms-key

Creates a customer-managed AWS KMS key (CMK) for encryption at rest, hardened for
HIPAA / SOC 2 by default. This is the **producer** of the keys that every other
Pillar-1 module consumes via their `kms_key_arn` input.

## Compliance posture

This module is **compliant by default** and refuses (at `tofu plan`) inputs
that would break that posture:

| Control | Setting | How it's enforced | Pillar |
|---|---|---|---|
| Encryption at rest | CMK created, no SSE defaults elsewhere | always a key | 1 |
| Key rotation | `enable_key_rotation = true`, **no toggle** | hard-coded ON | 1 / SOC 2 CC6.6 |
| Deletion protection | `deletion_window_in_days >= 30` | plan-time validation + `prevent_destroy` | 6 |
| Least privilege | key policy grants are explicit ARNs only; account root keeps `kms:*` scoped to its own account | policy generation rejects `"*"` principals | 2 |
| Data residency | `phi` ⇒ `sovereign_only = true` and `multi_region = false` | plan-time `precondition` | 7 |
| Region control | `region` must be in `allowed_regions`; `Region` tag applied | plan-time `precondition` + tags | 4 |
| Auditability | tags carry `DataClassification`, `Environment`, `Region`, `CostCenter`, `Project` | `locals.tf` base tags | 7/10 |

There is **no "encryption disabled" toggle** and **no rotation-off knob** —
both would violate the Well-Architected Framework and SOC 2 CC6.6, so neither is configurable.

## Usage

```hcl
module "app_key" {
  source = "git::https://github.com/anestoa/infrastructure.git//modules/aws/kms-key?ref=v1.0.0"

  account_id          = "123456789012"
  environment         = "prod"
  data_classification = "phi"
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }
  kms = {
    description    = "app PHI data key"
    iam_principals = ["arn:aws:iam::123456789012:role/app-reader"]
    admins         = ["arn:aws:iam::123456789012:role/kms-admin"]
  }
  cost_controls = {
    cost_center  = "ops"
    project_code = "app"
  }
}

# Consume it elsewhere for encryption at rest:
# module "s3" { source = ".../s3-bucket"; kms_key_arn = module.app_key.key_arn }
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_id` | string | *(required)* | Account that owns the key (scopes the root-policy grant). |
| `environment` | string | *(required)* | dev/test/staging/prod/commercial. |
| `region` | string | *(required)* | Target region; must be in `allowed_regions` (Pillar 4, plan-time precondition). |
| `data_classification` | string | `internal` | internal/pii/phi/financial/cardholder. |
| `data_residency` | object | — | `sovereign_only`, `jurisdiction`, etc. |
| `kms.alias_prefix` | string | `""` | Alias prefix, e.g. `app-`. |
| `kms.description` | string | derived | Purpose of the key. |
| `kms.key_spec` | string | `SYMMETRIC_DEFAULT` | Key spec. |
| `kms.usage` | string | `ENCRYPT_DECRYPT` | Key usage. |
| `kms.deletion_window_days` | number | `30` | ≥ 30 enforced. |
| `kms.multi_region` | bool | `false` | Multi-region (denied for PHI). |
| `kms.iam_principals` | list(string) | *(required, ≥1)* | Principals that may use the key. |
| `kms.admins` | list(string) | `[]` | Principals that may administer the key. |
| `cost_controls` | object | — | `cost_center`, `project_code`. |
| `allowed_regions` | list(string) | approved set | Region allowlist. |
| `default_tags` | map(string) | `{}` | Base tags. |

## Outputs

| Name | Description |
|---|---|
| `key_id` | Key ID. |
| `key_arn` | Key ARN (feed to consuming modules' `kms_key_arn`). |
| `alias_arn` | Alias ARN. |
| `key_name` | Derived human-readable name. |
| `compliance_controls` | Machine-readable compliance state for OPA/drift. |

## Examples

- `examples/basic-usage/` — minimal compliant key, wired to a consuming bucket.

## Tests

```bash
cd modules/aws/kms-key
tofu fmt -check
tofu validate
tofu test tests/
```

14 assertions cover: rotation locked on, deletion window ≥ 30, alias shape,
least-privilege policy, and **expect_failures** for PHI-multi-region, short
deletion window, PHI-not-sovereign, and empty-principal configs.

## Notes

- Shared module: declares **no provider block and no backend**; the caller
  supplies both. The `.tftest.hcl` files add a test-only provider with
  credential-checking disabled so plan-only tests run offline.
- `account_id` is an explicit variable, not derived from `data` at runtime, so
  plans validate in CI without AWS credentials.
