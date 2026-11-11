# Network — VPC, TGW Attachment, VPC Endpoints

> Part of `environments/production/data-platform/`. Apply second (after `iam/`).
> Reads nothing from remote state — all inputs are variables or direct module outputs.

## Purpose

Creates the private VPC, attaches it to the Network Hub Transit Gateway, and provisions
VPC endpoints for private AWS service access.

### What it creates

| Resource | Module | Purpose |
|----------|--------|---------|
| VPC | `vpc` | Private network with multi-AZ subnets for app/data/tgw tiers |
| VPC Flow Logs | `vpc` | Network traffic logs → immutable audit S3 bucket |
| TGW Attachment | `transit-gateway-attachment` | Connects this VPC to the Network Hub |
| Gateway Endpoints | `vpc-endpoint` | Free private S3 + DynamoDB access |
| Interface Endpoints | `vpc-endpoint` | Private SSM, STS, KMS, CloudWatch, ECR, Secrets Manager, AOSS |

### Default endpoint list

All interface endpoints are placed in privacy subnets and use the locked-down default SG:

| Endpoint | Subnet tier | Why |
|----------|-------------|-----|
| `ssm`, `ssmmessages`, `ec2messages` | app | Systems Manager for instance management |
| `sts` | app | STS credential vending |
| `kms` | app | KMS key operations |
| `monitoring`, `logs` | app | CloudWatch metrics and logs |
| `ecr.api`, `ecr.dkr` | app | ECR image pulls |
| `secretsmanager` | app | Secrets Manager access |
| `aoss` | data | OpenSearch Serverless (vector store) |

## Safety: blast radius

| Change | Blast radius | Why |
|--------|-------------|-----|
| Add endpoint | None | New entry in the endpoint list, no downstream impact |
| Change VPC CIDR | Medium | IDs stay the same, but downstream subnet lists need review |
| Add subnet tier | Low | New subnets appear in downstream plans as additions |
| Remove VPC | **Full** | You don't delete a VPC with resources in it — decommission only |

## Customization points

1. **CIDR ranges** — Set `vpc_cidr` and `subnets` to fit your organization's IPAM plan.
2. **Reserved CIDRs** — Pass the hub VPC CIDR and any existing spoke CIDRs to prevent overlap.
3. **Flow log destination** — Set `flow_log_destination.bucket_arn` to the immutable audit bucket ARN from the baseline.
4. **Interface endpoints** — Add or remove services from `interface_endpoints`.
5. **TGW ID** — Read from the Network Hub terraservice's remote state or SSM parameter.

## Pillar compliance

| Pillar | How it's met |
|--------|-------------|
| 1 — Encryption | Flow logs encrypted via SSE-S3 to immutable audit bucket |
| 3 — Network Isolation | Private subnets only, no public IPs, default SG locked to deny-all |
| 4 — HA | Multi-AZ subnets (≥2 AZs per tier) |
| 5 — Observability | VPC flow logs to centralized audit bucket |
| 8 — Auditability | Flow logs sent to immutable S3 (Object Lock COMPLIANCE) |
| 10 — FinOps | CostCenter and Project tags |
