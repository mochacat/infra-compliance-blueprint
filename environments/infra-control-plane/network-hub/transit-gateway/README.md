# network-hub / transit-gateway

> **Infra-team OWNED** control-plane layer. The shared Transit Gateway (TG) that every
> workload `network/` terraservice attaches to and routes through.

## Why a colocated TG + RAM share

One-of-a-kind shared infrastructure lives here as a **terraservice**, not a reusable module
(CLAUDE.md: "modules are not appliances"). The TG itself has no reusable module (the
`transit-gateway-attachment` module only *consumes* a `transit_gateway_id`), so it is
inlined here.

## Cross-account discovery (RAM, not SSM, not remote state)

Workload `network/` terraservices live in **different AWS accounts** than this hub. An SSM
parameter lives in one account and **cannot be read cross-account**, so cross-account TG
discovery uses **Resource Access Manager (RAM)**:

1. This hub creates `aws_ram_resource_share` + `aws_ram_principal_association` naming every
   workload account the TG is shared with (`participants` variable — least privilege, never a
   wildcard).
2. Each workload `network/` layer accepts the share (`aws_ram_resource_share_accepter`) and
   looks the shared TG up in **its own account** with `data.aws_ec2_transit_gateway` — same TG
   id on both sides, no cross-account SSM dependency.

```hcl
# workload/<env>/<bu>/network/
data "aws_ec2_transit_gateway" "hub" {
  tags = { Name = "network-hub-tgw" }   # arbitrary (after accept)
}
```

The SSM parameter remains as a **same-account / human pointer and audit trail** only — it is
NOT the cross-account contract. Real cross-account wiring is the RAM share.

## Resources

- `aws_ec2_transit_gateway.this` — the shared hub TG (private ASN 64512).
- `aws_ram_resource_share.this` + `aws_ram_resource_association` + `aws_ram_principal_association` — shares the TG with the named workload accounts (cross-account discovery).
- `aws_ssm_parameter.transit_gateway_id` — same-account/human pointer (encrypted with caller CMK).

## Compliance posture

| Pillar | Control | How |
|---|---|---|
| 2 | Least Privilege | `participants` names every workload account explicitly; no wildcard principals (`allow_external_principals = false`) |
| 3 | Network Security & Isolation | hub is the private backbone all workload VPCs join |
| 4 | HA & Region Control | `region` gated to `allowed_regions` via precondition, plan time |
| 7 | Data Residency | `data_classification` required; PHI requires `sovereign_only=true`, plan time |
| 10 | FinOps | `CostCenter` / `Project` / `Environment` tags |

Security posture is **invariant** across environments — only cost/sizing varies (see the
`create-workload` skill). This hub must never lower its own controls for a "dev" environment.

## Apply order

```
1. (this) infrastructure/network-hub/transit-gateway/   ← creates TG + RAM share
2. infrastructure/network-hub/endpoints/                ← shared VPC endpoints
3. <env>/<bu>/iam/
4. <env>/<bu>/network/                                  ← accepts RAM share, looks up TG locally, attaches
5. <env>/<bu>/data/
6. <env>/<bu>/compute/  and  <env>/<bu>/ai/
```

## Verify

```sh
make fmt-check MODULE_PATH=environments/infra-control-plane/network-hub/transit-gateway
make validate  MODULE_PATH=environments/infra-control-plane/network-hub/transit-gateway
make test      MODULE_PATH=environments/infra-control-plane/network-hub/transit-gateway
```

> This is a **reference** terraservice for an infra team to clone — it is not applied by
> default.