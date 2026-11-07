# deploy-role module

Creates the `opentofu-deploy` cross-account IAM role that CI/CD (Atlantis)
assumes to manage infrastructure in a specific account.

## Why not AdministratorAccess?

The baseline's central principle is **least privilege (Pillar 2 — Access Control & Least Privilege)**. A deploy
role with admin access is a single compromise away from everything. This role
is scoped to what automation actually does, and consumes a caller-provided
permissions boundary so it can never widen its own scope.

## Inputs

| Variable | Type | Default | Description |
|---|---|---|---|
| `role_name` | `string` | — | Name of the deploy role |
| `oidc_provider_arn` | `string` | — | OIDC provider ARN the role trusts |
| `allowed_subjects` | `list(string)` | `["repo:*:*:ref:refs/heads/main"]` | OIDC subjects allowed to assume |
| `permissions_boundary_arn` | `string` | `null` | Boundary ARN applied to the role (required in prod) |
| `tags` | `map(string)` | `{}` | Additional tags (merged with pillar tags) |
| `environment` | `string` | — | Environment: dev, test, staging, prod, commercial |
| `data_classification` | `string` | `"internal"` | Data classification: internal, pii, phi, financial, cardholder |
| `data_residency` | `object` | `{}` | Residency constraints (sovereign_only, jurisdiction, etc.) |
| `cost_controls` | `object` | `{ cost_center = null, project_code = null }` | Cost allocation tags |

## Outputs

| Output | Type | Description |
|---|---|---|
| `role_arn` | `string` | ARN of the created role |
| `role_name` | `string` | Name of the created role |
| `compliance_controls` | `object` | Compliance state for OPA / drift evaluation |

## Usage

```hcl
module "deploy_role" {
  source                 = "git::https://github.com/anestoa/infrastructure.git//modules/aws/deploy-role?ref=v1.0.0"
  role_name              = "opentofu-deploy"
  oidc_provider_arn      = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  allowed_subjects       = ["repo:anestoa/infrastructure:ref:refs/heads/main"]
  permissions_boundary_arn = "arn:aws:iam::123456789012:policy/cicd-boundary"
  environment            = "prod"
  tags                   = { ManagedBy = "tofu" }
}
```

## Pillar compliance

| Pillar | Status | Notes |
|--------|--------|-------|
| 2 — Access Control | ✅ | Scoped actions, permissions boundary, no admin access |
| 7 — Data Residency | ✅ | Classification + sovereignty gates enforced |
| 9 — Change Management | ✅ | Environment validated, compliance_controls output |
| 10 — FinOps | ✅ | CostCenter / Project tags via cost_controls |

## Note on the scope policy (`Resource = ["*"]`)

The deploy-role's inline scope policy intentionally uses `Resource = ["*"]`
for `Describe*`/`Get`/`Put` actions on state infrastructure (S3/DynamoDB).
This is a recognized exception to Pillar 2's no-wildcard rule — the **actions**
themselves are scoped, not a blanket admin grant. Consequently this module does
**not** ship an OPA rego that bans wildcard `Resource`, which would false-positive
on its own intended policy.

## Layered enforcement

This module enforces least-privilege inside the module. It is the first of three
layers: module defaults → SCP `aws:RequestTag` (org boundary) → OPA (platform
layer, catches raw `aws_iam_role` declared outside modules).