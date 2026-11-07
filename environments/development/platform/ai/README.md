# AI — GenAI Agentic Runtime

> Part of `environments/development/platform/`. Apply fifth (after `data/`).
> Reads remote state from `iam/` and `network/`. No downstream dependents.

## Purpose

Creates the AI/ML development environment for building and deploying GenAI agents.

| Resource | Module | Purpose |
|----------|--------|---------|
| SageMaker Studio Domain | `sagemaker-domain` | Private IDE for data scientists and ML engineers |
| Bedrock Endpoint | *deferred* | Managed model inference for agents |
| Bedrock Guardrail | *deferred* | Content safety, PII redaction, prompt injection defense |

### Dev-specific sizing

| Setting | Value | Why |
|---------|-------|-----|
| Studio instance | ml.t3.medium | Smallest, cheapest for dev |
| Shutdown outside hours | true | Stop Studio apps overnight to save cost |
| Auth mode | IAM | Simple for dev; SSO for prod |
| Default user | Created | Single user profile for dev team |

## Safety: blast radius

| Change | Blast radius | Why |
|--------|-------------|-----|
| Change Studio instance type | None | Resize the app, no downstream impact |
| Add a new user profile | None | New profile, no downstream impact |
| Modify execution role policies | Low (in iam/) | Role ARN stays the same |
| Delete SageMaker domain | Low | No downstream dependents — EFS data is in a separate lifecycle |

## Remote state contract

**Reads** from `iam/` and `network/`:
- `iam.sagemaker_execution_role_arn` → runtime role
- `iam.sagemaker_execution_role_name` → domain execution role config
- `iam.app_kms_key_arn` → KMS encryption
- `network.vpc_id`, `network.app_subnet_ids` → network placement
- `network.default_security_group_id` → security

**Exports** (no downstream dependents currently)

## Customization points

1. **Studio instance type** — Set `cost_controls.studio_instance_type` for different workloads (e.g., `ml.g5.xlarge` for GPU)
2. **Auth mode** — Switch to `SSO` when IAM Identity Center is configured
3. **User profiles** — Add more profiles in the module config for each team member
4. **Bedrock modules** — Uncomment the bedrock-endpoint and bedrock-guardrail modules when ready
5. **Data buckets** — Set `sagemaker_bucket_arns` to grant the execution role access to training data

## Pillar compliance

| Pillar | How it's met |
|--------|-------------|
| 1 — Encryption | KMS-encrypted EFS home, EBS, FSx |
| 2 — Access Control | Dedicated SageMaker execution role, scoped policies |
| 3 — Network Isolation | ALWAYS VpcOnly — no public internet access |
| 4 — HA | Domain spans ≥ 2 AZs (multi-AZ by construction) |
| 5 — Observability | CloudWatch alarm for Studio health, execution logging |
| 6 — Backup/DR | EFS auto-versioning, log retention |
| 10 — FinOps | Dev-sized ml.t3.medium, outside-hours shutdown |
