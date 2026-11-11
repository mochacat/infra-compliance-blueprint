# IAM — Application Roles

> Part of `environments/preprod/platform/`. Apply first — no dependencies.

## Purpose

Creates the IAM roles and a dev KMS key used by downstream layers in this account.

| Role | Assumed by | Used by |
|------|-----------|---------|
| `ecs-task-exec` | `ecs-tasks.amazonaws.com` | compute/ — pulling images, writing logs |
| `ecs-service` | `ecs-tasks.amazonaws.com` | compute/ — app code calling AWS APIs |
| `sagemaker-execution` | `sagemaker.amazonaws.com` | ai/ — SageMaker Studio domains |
| `rds-proxy` | `rds.amazonaws.com` | data/ — RDS Proxy auth |

## Safety: why this layer is safe to change

- **Adding a new role** — zero blast radius. Downstream layers don't reference it until you add an SSM data source for it.
- **Adding a policy to an existing role** — low blast radius. Downstream layers read the role ARN from SSM, not the policy content. New permissions are available on their next plan refresh.
- **Removing a role** — **caught at plan time**. Downstream layers fail validation because the SSM parameter is gone. Check `ssm-contract.yaml` first.

## Cross-layer contract (SSM-only)

Downstream layers read these outputs from `iam/` via SSM Parameter Store (never `terraform_remote_state`):

- `ecs_task_exec_role_arn` / `ecs_service_role_arn` → compute/
- `sagemaker_execution_role_arn` / `sagemaker_execution_role_name` → ai/
- `rds_proxy_role_arn` → data/
- `app_kms_key_arn` → network/, data/, compute/, ai/

> **Never remove a published SSM parameter** without checking `ssm-contract.yaml` for all downstream consumers.

## Pillar compliance

| Pillar | How it's met |
|--------|-------------|
| 1 — Encryption | KMS key created (or caller-provided). Every role may `kms:Decrypt` with this key. |
| 2 — Access Control | Dedicated role per resource. Scoped policy statements (no wildcard `Action` or `Resource`). Permissions boundary support. |
| 7 — Data Residency | `data_classification` and `data_residency` passed through to each role module. |
| 9 — Change Management | `compliance_controls` output exposes compliance state for OPA evaluation. |
| 10 — FinOps | CostCenter and Project tags on every resource. |

## Customization points

1. **Role policies** — Open up `main.tf` and modify `policy_statements` for each role to match your app's actual AWS API needs.
2. **Trust relationships** — Adjust `trust_policy` JSON if you use cross-account access patterns.
3. **KMS key** — In production, pass `kms_key_arn` from a centrally-managed key instead of letting this layer create one.
