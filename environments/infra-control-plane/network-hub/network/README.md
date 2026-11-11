# network-hub / network

> **Infra-team OWNED** control-plane layer. Creates the hub VPC, attaches it to the
> shared Transit Gateway, and deploys shared VPC endpoints for hub-account services.

## Apply order

```
1. transit-gateway/          ← TG + RAM share (TG id is an input to this layer)
2. network/ (this)           ← Hub VPC + TGW attachment + endpoints + SSM publication
3. <env>/<bu>/iam/
4. <env>/<bu>/network/
5. <env>/<bu>/data/
6. <env>/<bu>/compute/  and  <env>/<bu>/ai/
```

## Resources

- **Hub VPC** — 3 tiers × 2 AZs (app, data, tgw). RFC-6598 `100.64.0.0/24` default (distinct from spoke RFC-1918 spaces).
- **TGW attachment** — attaches the hub VPC to the same-account Transit Gateway (created by `transit-gateway/`).
- **Route tables** — one private route table per tier, default route through the TGW.
- **VPC endpoints** — Gateway (S3, DynamoDB) + Interface (SSM, STS, KMS, CloudWatch, ECR, Logs, Secrets Manager).
- **SSM parameters** — hub VPC coordinates published for infra-team tools and audits.

## CIDR overlap prevention

The hub VPC CIDR must not overlap with any spoke VPC CIDR (otherwise routing breaks).

| Layer | Mechanism | What it checks |
|---|---|---|
| **Module** | `reserved_cidrs` on `vpc` module | Prevents VPC module from creating subnets in conflicting ranges |
| **OPA** | `policies/network.rego` | Denies plan if hub CIDR overlaps with any entry in `spoke_cidrs` variable |
| **Variable** | `spoke_cidrs` declaration | Explicit inventory of all spoke CIDRs; required in prod |

## Compliance posture

| Pillar | Control | How |
|---|---|---|
| 3 | Network Security & Isolation | Private subnets only, VPC endpoints, CIDR overlap prevention (OPA + module), no `0.0.0.0/0` ingress |
| 4 | HA & Region Control | Multi-AZ (2 AZs per tier), region gated to `allowed_regions` |
| 5 | Observability | VPC flow logs to centralized audit bucket (when `flow_log_destination` configured) |
| 7 | Data Residency | `data_classification` + `data_residency` with PHI-sovereign gate |
| 10 | FinOps | `CostCenter` / `Project` / `Environment` tags on every resource |

## Variable overview

| Variable | Type | Default | Description |
|---|---|---|---|
| `vpc_cidr` | `string` | `100.64.0.0/24` | Hub VPC CIDR. Must not overlap with spokes. |
| `subnets` | `map(object)` | 3 tiers × 2 AZs | Subnet layout: app, data, tgw tiers. |
| `spoke_cidrs` | `list(object)` | `[]` | Declared spoke VPC CIDRs for OPA overlap check. Required in prod. |
| `transit_gateway_id` | `string` | — | TG id from `transit-gateway/` terraservice (required). |
| `interface_endpoints` | `list(object)` | SSM, STS, KMS, CloudWatch, ECR, Logs, Secrets Manager | Interface endpoints to deploy. |
| `enable_gateway_endpoints` | `bool` | `true` | Deploy S3 + DynamoDB gateway endpoints. |
| `flow_log_destination` | `object` | `null` | S3 bucket ARN for VPC flow logs. Required in prod. |

## Verify

```sh
make fmt-check MODULE_PATH=environments/infra-control-plane/network-hub/network
make validate  MODULE_PATH=environments/infra-control-plane/network-hub/network
make test      MODULE_PATH=environments/infra-control-plane/network-hub/network
```

> This is a **reference** terraservice for an infra team to clone — it is not applied by default.
