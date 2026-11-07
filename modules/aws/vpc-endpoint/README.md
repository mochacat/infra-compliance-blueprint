# aws/vpc-endpoint

Creates **private VPC Endpoints** — both Gateway (S3, DynamoDB) and Interface
(SSM, STS, KMS, CloudWatch, ECR, etc.) — for workload and shared VPCs. Keeps all
traffic within the AWS network, with **no public internet egress**, which is the
transmission-security control required by **HIPAA 164.312(e)(1)** and
**SOC 2 CC6.7**.

## Compliance posture

| Control | Setting | How it's enforced | Pillar |
|---|---|---|---|
| Transmission security | all endpoints are private (Gateway/Interface), never public | no `Service` endpoint type; deny-all posture | 3 |
| Least privilege | endpoint policy caller-provided, defaults to AWS default | `endpoint_policy` variable | 2 |
| High availability | interface endpoints span ≥ 2 AZs | lifecycle precondition + OPA rule | 4 |
| Region control | `region` must be in `allowed_regions` | plan-time precondition + OPA rule | 4 |
| Residency | `phi` ⇒ `sovereign_only = true` | plan-time precondition + OPA rule | 7 |
| FinOps | `CostCenter` / `Project` tags on every endpoint | `locals.tf` base_tags | 10 |

The module **never** creates a public/service endpoint, never exposes an internet
gateway, and keeps interface endpoints multi-AZ by default.

## Usage

```hcl
module "vpc_endpoints" {
  source = "git::https://github.com/anestoa/infrastructure.git//modules/aws/vpc-endpoint?ref=v1.0.0"

  environment         = "prod"
  name                = "core"
  region              = "us-east-1"
  vpc_id              = module.vpc.vpc_id
  data_classification = "internal"

  # Free Gateway endpoints — add prefix-list routes to route tables.
  gateway_endpoints = [
    { service = "s3", route_table_ids = [module.vpc.private_route_table_ids[0]] },
  ]

  # Interface endpoints — private DNS, multi-AZ.
  interface_endpoints = [
    { service = "ssm", subnet_ids = module.vpc.subnet_ids["app-*"] },
    { service = "sts", subnet_ids = module.vpc.subnet_ids["app-*"] },
    { service = "kms", subnet_ids = module.vpc.subnet_ids["app-*"] },
  ]

  security_group_ids = [module.vpc.default_security_group_id]

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
| `name` | string | *(required)* | Endpoint name prefix + tags. |
| `allowed_regions` | list(string) | 4 approved | Region allowlist (Pillar 4 — High Availability & Region Control). |
| `region` | string | *(required)* | Target region; must be in `allowed_regions`. |
| `vpc_id` | string | *(required)* | VPC to create endpoints in. |
| `gateway_endpoints` | list(object) | `[]` | `{ service, route_table_ids }` — S3/DynamoDB. |
| `interface_endpoints` | list(object) | `[]` | `{ service, subnet_ids, private_dns_enabled }`. |
| `security_group_ids` | list(string) | `[]` | SGs for interface endpoints (least privilege). |
| `endpoint_policy` | any | `null` | IAM policy applied to all endpoints; `null` = AWS default. |
| `data_classification` | string | `internal` | internal/pii/phi/financial/cardholder. |
| `data_residency` | object | `{}` | `sovereign_only`, `jurisdiction`, etc. |
| `cost_controls` | object | — | `cost_center`, `project_code`. |
| `default_tags` | map(string) | `{}` | Base tags merged onto every resource. |

## Outputs

| Name | Description |
|---|---|
| `gateway_endpoint_ids` | Map of service → gateway endpoint ID. |
| `gateway_endpoint_arns` | Map of service → gateway endpoint ARN. |
| `interface_endpoint_ids` | Map of service → interface endpoint ID. |
| `interface_endpoint_dns_entries` | Map of service → DNS entries for private resolution. |
| `endpoint_count` | Total endpoint count. |
| `compliance_controls` | Machine-readable compliance state for OPA/drift. |

## Tests

```bash
cd modules/aws/vpc-endpoint
tofu fmt -check
tofu validate
tofu test tests/
```

Assertions cover: no endpoints by default, gateway + interface endpoint creation
with correct type/service/private-DNS, multi-AZ interface endpoints, endpoint
policy applied, CostCenter/Environment tags, and **expect_failures** for
single-AZ interface endpoints, unapproved regions, and PHI-not-sovereign.

## Notes

- Shared module: declares **no provider block and no backend**; the caller
  supplies both.
- **Gateway vs Interface cost:** Gateway endpoints (S3, DynamoDB) are **free**.
  Interface endpoints cost ~$7.20/mo each + data processing. Use Gateway
  endpoints for S3/DynamoDB where possible, Interface for everything else —
  and only for the services the VPC actually uses (least privilege, FinOps).
- `security_group_ids` applies to **all** interface endpoints. Scope the SG to
  allow only the specific service traffic each endpoint carries.
- Endpoints are **discretionary** (`gateway_endpoints` / `interface_endpoints`
  default to empty) so the module plans offline; a real workload configures the
  services it needs.

## Examples

- `examples/basic-usage/` — S3 Gateway + SSM/STS/KMS Interface endpoints with a
  least-privilege S3 endpoint policy.