# aws/transit-gateway-attachment

Attaches a workload VPC to the **central Network Hub Transit Gateway** in a
hub-and-spoke topology. Every workload environment (`production/platform/network/`,
`development/platform/network/`, etc.) uses this module to connect its VPC to the
hub for inter-VPC routing and centralized network inspection.

## Why Transit Gateway (not VPC Peering)?

For a regulated multi-account architecture under HIPAA and SOC 2 Type II, Transit
Gateway is the correct choice — even for early-stage teams who will grow into it:

| Requirement | TGW | VPC Peering | Why it matters |
|---|---|---|---|
| **Centralized network inspection** | ✅ Single inspection VPC at hub | ❌ Must peer every pair | HIPAA 164.312(a)(1) — every cross-VPC flow must be inspectable at a single point. With TGW, you attach a Network Firewall or third-party appliance in the Network Hub and all spoke-spoke traffic routes through it. Peering creates a mesh — no single choke point. |
| **Centralized egress** | ✅ Single NAT GW / egress VPC | ❌ Each spoke needs its own | SOC 2 CC6.6 — all outbound traffic can flow through a single inspection/egress VPC. No unmonitored egress paths. |
| **Route table management** | 1 hub RT + 1 per spoke | N×(N-1)/2 peerings | At 5 VPCs: 10 peerings. At 10 VPCs: 45 peerings. TGW stays linear. |
| **Cost at small scale (3-5 VPCs)** | ~$110-183/mo attachments | ~$0 | The premium you pay for centralized inspection. Acceptable from Series A (~$5k+/mo AWS spend). |
| **Migration from peering** | Transitive — attach, re-route, drop peerings | N/A | Teams that start < 5 VPCs on peering can migrate without recreating VPCs. |

For **pre-seed / seed teams** that don't yet need centralized inspection, VPC
Peering is a valid interim path. Create a flat mesh until you hit 5+ VPCs or
require Network Firewall, then migrate to TGW using this module.

## Compliance posture

| Control | Setting | Pillar |
|---|---|---|
| Network isolation | Attachment uses dedicated TGW subnets (no 0.0.0.0/0 routes) | 3 |
| Least privilege | Minimum IAM (no `ec2:DeleteTransitGatewayVpcAttachment`) | 2 |
| High availability | Attachments span ≥ 2 AZs | 4 |
| Auditability | Resource tags carry Environment, CostCenter, DataClassification | 5/8/10 |
| Observability | `compliance_controls` output feeds OPA policy engine | 5 |
| Residency | `data_classification` / `sovereign_only` gates on cross-region | 7 |
| DR/Backup | Not applicable — attachment is stateless | 6 (n/a) |

## Usage

```hcl
module "tgw_attachment" {
  source = "git::https://github.com/anestoa/infrastructure.git//modules/aws/transit-gateway-attachment?ref=v1.0.0"

  environment         = "prod"
  name                = "core"
  region              = "us-east-1"
  transit_gateway_id  = aws_ec2_transit_gateway.hub.id
  vpc_id              = module.vpc.vpc_id
  subnet_ids = [
    module.vpc.subnet_ids["tgw-us-east-1a"],
    module.vpc.subnet_ids["tgw-us-east-1b"],
  ]
  data_classification = "internal"

  cost_controls = {
    cost_center  = "ops"
    project_code = "core-app"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `environment` | string | *(required)* | dev/test/staging/prod/commercial. |
| `name` | string | *(required)* | Human label; prefixes resource names + tags. |
| `region` | string | *(required)* | Target region; must be in `allowed_regions`. |
| `allowed_regions` | list(string) | 4 approved | Region allowlist (Pillar 4 — High Availability & Region Control). |
| `transit_gateway_id` | string | *(required)* | The Network Hub's Transit Gateway ID. |
| `vpc_id` | string | *(required)* | The workload VPC ID to attach. |
| `subnet_ids` | list(string) | *(required)* | TGW-tier subnet IDs (≥ 2 AZs, max per TGW limits). |
| `dns_support` | bool | `true` | Enable DNS support on the attachment. |
| `ipv6_support` | bool | `false` | Enable IPv6 on the attachment. |
| `appliance_mode_support` | string | `"disable"` | Set to `"enable"` when the Network Hub has a firewall appliance for centralized inspection. |
| `auto_accept` | bool | `true` | Auto-accept the attachment request. |
| `data_classification` | string | `internal` | internal/pii/phi/financial/cardholder. |
| `data_residency` | object | `{}` | Residency constraints + jurisdiction. |
| `cost_controls` | object | — | `cost_center`, `project_code`. |
| `default_tags` | map(string) | `{}` | Base tags merged onto every resource. |

## Outputs

| Name | Description |
|---|---|
| `attachment_id` | The TGW attachment ID (tgw-attach-xxx). |
| `attachment_arn` | The TGW attachment ARN. |
| `transit_gateway_id` | The hub TGW ID (passthrough for convenience). |
| `compliance_controls` | Machine-readable compliance state for OPA/drift. |

## Tests

```bash
cd modules/aws/transit-gateway-attachment
tofu fmt -check
tofu validate
tofu test tests/
```

Assertions cover: attachment spans ≥ 2 AZs, tags present, `compliance_controls`
reports environment/classification, expect_failures on sovereign PHI in wrong
region, insufficient AZs.

## Network inspection workflow

```
                    ┌───────────────────┐
                    │   Network Hub      │
                    │  (inspection VPC)  │
                    │                    │
                    │  ┌─ Firewall ───┐  │
                    │  │ Appliance    │  │
                    │  │ or NGFW      │  │
                    │  └──────────────┘  │
                    │         │          │
                    │  Transit Gateway   │
                    └────┬────┬────┬─────┘
                         │    │    │
              ┌──────────┘    │    └──────────┐
              ▼               ▼               ▼
     ┌────────────────┐ ┌────────────┐ ┌──────────────┐
     │ Production VPC │ │ Staging VPC│ │  Dev VPC     │
     │ (attached via  │ │ (attached  │ │ (attached    │
     │  this module)  │ │  via this) │ │  via this)   │
     └────────────────┘ └────────────┘ └──────────────┘
```

When `appliance_mode_support = "enable"`, the TGW attachment signals to the hub
that traffic to/from this VPC should be routed through the TGW route table that
points to the firewall appliance. All inter-spoke traffic (prod→dev, prod→shared)
passes through the firewall for inspection — this is the single audit point that
satisfies **SOC 2 CC6.7** (transmission security) and **HIPAA 164.312(a)(1)**
(access control) in a multi-VPC architecture.

## Notes

- Shared module: declares **no provider block and no backend**; the caller
  supplies both.
- The `subnet_ids` argument must contain at least 2 subnet IDs in different AZs
  (Pillar 4 — High Availability & Region Control) and at most one per AZ (TGW limit). Use the `tgw` tier subnets
  from the `vpc` module.
- When migrating from VPC Peering, attach via this module, add the TGW route in
  the VPC route tables, verify traffic, then remove the stale VPC peering
  connections.