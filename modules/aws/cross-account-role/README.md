# cross-account-role module

Creates an IAM role whose trust policy is **pinned to explicit source
accounts** — no wildcard principals. Use it to let a specific role/account
assume a role in this account to reach shared resources (e.g. an audit or
analytics role).

This is a specialization of `iam-role`: same least-privilege posture, but the
trust policy is generated from a list of source-account ARNs and can carry an
`ExternalId` / MFA / session-tag condition.

## Pillars

| Pillar | Coverage |
|---|---|
| 2  Access control | Trust pinned to explicit accounts, ExternalId support, permissions boundary, no wildcard statements |
| 7  Data residency | `data_classification` + `data_residency` tags and gates |
| 9  Change mgmt   | `environment` validated, `compliance_controls` output for OPA |
| 10 FinOps        | `CostCenter` / `Project` / `Environment` tags |

## Inputs

| Variable | Type | Description |
|---|---|---|
| `environment` | string | dev/test/staging/prod/commercial |
| `name` | string | Role name (prefixed `cross-account-`) |
| `source_account_arns` | list(string) | Accounts/roles allowed to assume — ARN-validated |
| `trust_conditions` | object | Optional ExternalId/MFA/session-tag condition |
| `policy_statements` | list(object) | Scoped delegation statements — wildcards rejected |
| `permissions_boundary_arn` | string | Boundary ARN (required in prod) |
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
| `trust_policy` | Rendered trust policy JSON |
| `compliance_controls` | OPA / drift-eval surface (Pillar 9 — Change Management & Policy Enforcement) |

## Usage

```hcl
module "log_reader" {
  source = "git::https://github.com/anestoa/infrastructure.git//modules/aws/cross-account-role?ref=v1.0.0"

  environment = "dev"
  name        = "log-reader"

  source_account_arns = [
    "arn:aws:iam::111111111111:role/SecurityAudit",
  ]

  trust_conditions = {
    test     = "StringEquals"
    variable = "sts:ExternalId"
    values   = ["audit-external-id"]
  }

  policy_statements = [
    {
      sid       = "ReadLogArchive"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:ListBucket"]
      resources = ["arn:aws:s3:::log-archive", "arn:aws:s3:::log-archive/*"]
    }
  ]

  permissions_boundary_arn = "arn:aws:iam::222222222222:policy/cross-account-boundary"
}
```

## Compliance posture

- **Access Control & Least Privilege (Pillar 2):** trust pinned to explicit ARNs (no `Principal: "*"`),
  wildcard statements rejected, permissions boundary required in prod,
  `ExternalId` optional but recommended for cross-account trust.
- **Data Residency & Sovereignty (Pillar 7):** PHI requires `sovereign_only = true`.
- **FinOps & Cost Controls (Pillar 10):** mandatory cost tags on every role.

## Tests

Run `tofu test tests/` — covers defaults, prod-grade inputs, and compliance
gates (`expect_failures` on wildcards, malformed source ARN, missing boundary,
PHI misconfiguration).

## OPA / layered enforcement

Same layered model as `iam-role`: module-level plan-time enforcement, plus
SCP `aws:RequestTag` (org boundary) and OPA (platform layer, catches raw
`aws_iam_role` declared outside the module).