# iam-role module

Creates a least-privilege IAM role for AI/regulated workloads. The module
rejects wildcard `Action` / `Resource` in policy statements, requires a
permissions boundary in prod, and applies mandatory cost/compliance tags.

## Why not a managed role?

The platform principle is **least privilege (Pillar 2 — Access Control & Least Privilege)**. This module makes it
impossible to accidentally create a broad role: inline statements are validated
to be free of `"*"`, a permissions boundary is enforced in production, and every
role carries `Environment`, `DataClassification`, `CostCenter`, and `ManagedBy`
tags for attribution (SOC 2 CC6.1 / HIPAA §164.312(a)(1)).

## Pillars

| Pillar | Coverage |
|---|---|
| 2  Access control | Scoped statements (no `*`), permissions boundary, no broad managed policies |
| 7  Data residency | `data_classification` + `data_residency` tags and gates |
| 9  Change mgmt   | `environment` validated, `compliance_controls` output for OPA |
| 10 FinOps        | `CostCenter` / `Project` / `Environment` tags |

## Inputs

| Variable | Type | Description |
|---|---|---|
| `environment` | string | dev/test/staging/prod/commercial |
| `name` | string | Role name |
| `trust_policy` | string | JSON trust (assume-role) policy |
| `policy_statements` | list(object) | Scoped inline statements — wildcards rejected |
| `permissions_boundary_arn` | string | Boundary ARN (required in prod) |
| `managed_policy_arns` | list(string) | Optional managed policies (use sparingly) |
| `max_session_duration` | number | 3600–43200 seconds |
| `path` | string | IAM path (default `/`) |
| `data_classification` | string | internal/pii/phi/financial/cardholder |
| `data_residency` | object | Sovereign/cross-border constraints |
| `cost_controls` | object | `cost_center`, `project_code` |
| `default_tags` | map(string) | Extra tags |

## Outputs

| Output | Description |
|---|---|
| `role_name` | Role name |
| `role_arn` | Role ARN |
| `role_unique_id` | Unique ID |
| `compliance_controls` | OPA / drift-eval surface (Pillar 9 — Change Management & Policy Enforcement) |

## Usage

```hcl
module "app_role" {
  source = "git::https://github.com/anestoa/infrastructure.git//modules/aws/iam-role?ref=v1.0.0"

  environment         = "dev"
  name                = "app-role"
  data_classification = "internal"

  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  policy_statements = [
    {
      sid       = "S3Read"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:ListBucket"]
      resources = ["arn:aws:s3:::app-data-bucket", "arn:aws:s3:::app-data-bucket/*"]
    }
  ]

  permissions_boundary_arn = "arn:aws:iam::123456789012:policy/app-boundary"
}
```

## Compliance posture

- **Encryption (Pillar 1 — Encryption):** N/A — roles have no data at rest.
- **Access Control & Least Privilege (Pillar 2):** wildcard `Action`/`Resource` rejected at plan time;
  permissions boundary required in prod.
- **Data Residency & Sovereignty (Pillar 7):** PHI requires `sovereign_only = true`.
- **FinOps & Cost Controls (Pillar 10):** mandatory cost tags on every role.

## Tests

Run `tofu test tests/` — covers defaults, prod-grade inputs, and compliance
gates (`expect_failures` on wildcards, missing boundary, PHI misconfiguration).

## OPA / layered enforcement

This module enforces compliance **inside the module** at plan time. It is the
first of three layers:

1. **Module defaults** — compliant-by-default here.
2. **SCP `aws:RequestTag`** — denies any `Create*` call that omits mandatory tags
   org-wide (catches raw resources created outside modules).
3. **OPA (platform)** — re-verifies root-module resources declared directly
   (outside this module) so a raw `aws_iam_role` with blanket access is blocked
   at plan time in the terraservice CI.

See the landing-zone SCP catalog and the OPA docs for layers 2 and 3.