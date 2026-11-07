# aws/vpc

Creates a compliant-by-default VPC for AI / regulated workloads: private-only
private subnets spread across AZs, VPC Flow Logs shipped to an immutable
cross-account audit bucket (Parquet, Athena-queryable), a deny-all default
security group, and RFC-1918 CIDR planning with overlap protection for a
hub-and-spoke topology.

## Compliance posture

This module is **compliant by default** and refuses (at `tofu plan`) inputs that
would break that posture:

| Control | Setting | How it's enforced | Pillar |
|---|---|---|---|
| Network isolation | private subnets only, no public IPs, no `0.0.0.0/0` | subnets tagged `Network=private`; no IGW/routetable routes | 3 |
| CIDR hygiene | RFC-1918 `/16–/28` only; **no overlaps** against `reserved_cidrs` | plan-time variable validation + lifecycle precondition | 3 |
| Default SG lockdown | AWS default SG replaced with a deny-all posture | `aws_default_security_group.this` | 3 |
| High availability | each tier spans ≥ 2 AZs, multi-AZ enforced | subnet for_each across AZs; `subnet_az_count` output | 4 |
| Region control | `region` must be in `allowed_regions` | plan-time precondition + `Region` tag | 4 |
| Observability | VPC Flow Logs → immutable cross-account audit S3 bucket (Parquet) | `aws_flow_log` + dedicated IAM role | 5 |
| Auditability | flow logs land in an offsite Log Archive bucket | caller-provided `flow_log_destination.bucket_arn` | 5 / 8 |
| Data residency | `phi` ⇒ `sovereign_only = true` | plan-time precondition | 7 |
| FinOps | `CostCenter` / `Project` tags on every resource | `locals.tf` base_tags | 10 |

The module **never** exposes a public-IP opt-in knob, never creates an internet
gateway or a `0.0.0.0/0` route, and **requires** a caller-provided flow log
destination (it does not make its own SNS/S3). Flow logs are optional only by
explicit destination omission; when set, they always go to the immutable
audit bucket.

## Usage

```hcl
module "workload_vpc" {
  source = "git::https://github.com/anestoa/infrastructure.git//modules/aws/vpc?ref=v1.0.0"

  environment         = "prod"
  name                = "core"
  region              = "us-east-1"
  cidr_block          = "10.40.0.0/16"
  reserved_cidrs      = ["10.0.0.0/16"]          # hub VPC + existing spokes
  data_classification = "phi"
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }
  flow_log_destination = {
    bucket_arn              = module.audit.audit_bucket_arn  # Log Archive bucket
    bucket_owner_account_id = "123456789012"
  }
  subnets = {
    app = {
      availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
      cidrs              = ["10.40.1.0/24", "10.40.2.0/24", "10.40.3.0/24"]
    }
    data = {
      availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
      cidrs              = ["10.40.4.0/24", "10.40.5.0/24", "10.40.6.0/24"]
    }
  }
  cost_controls = {
    cost_center  = "ops"
    project_code = "core-app"
  }
}
```

Wire the produced `subnet_ids` into downstream compute / data / GenAI modules
for private placement.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `environment` | string | *(required)* | dev/test/staging/prod/commercial. |
| `name` | string | *(required)* | VPC name; prefixes subnet naming + tags. |
| `cidr_block` | string | *(required)* | RFC-1918 private range, prefix `/16–/28`. |
| `reserved_cidrs` | list(string) | `[]` | Existing CIDRs the VPC must **not** overlap. |
| `allowed_regions` | list(string) | 4 approved | Region allowlist (Pillar 4 — High Availability & Region Control). |
| `region` | string | *(required)* | Target region; must be in `allowed_regions`. |
| `subnets` | map(object) | `{}` | Per-tier `{ availability_zones, cidrs }` — each tier spans ≥ 2 AZs. |
| `flow_log_destination` | object | `null` | `{ bucket_arn, bucket_owner_account_id }` → immutable audit bucket. |
| `data_classification` | string | `internal` | internal/pii/phi/financial/cardholder. |
| `data_residency` | object | `{}` | `sovereign_only`, `jurisdiction`, etc. |
| `cost_controls` | object | — | `cost_center`, `project_code`. |
| `default_tags` | map(string) | `{}` | Base tags merged onto every resource. |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID. |
| `vpc_arn` | VPC ARN. |
| `vpc_cidr_block` | The VPC's CIDR. |
| `subnet_ids` | Map of `tier-az` → subnet ID for private placement. |
| `subnet_arns` | Map of `tier-az` → subnet ARN. |
| `flow_log_id` | Flow Log ID (null if destination not set). |
| `flow_log_role_arn` | IAM role used for S3 delivery (null if destination not set). |
| `default_security_group_id` | Deny-all default SG ID. |
| `compliance_controls` | Machine-readable compliance state for OPA/drift. |

## Examples

- `examples/basic-usage/` — forward reference to the module with a compliant
  multi-AZ VPC and a flow-log destination to an audit bucket.

## Tests

```bash
cd modules/aws/vpc
tofu fmt -check
tofu validate
tofu test tests/
```

Assertions cover: DNS on, multi-AZ subnet spread, private-only posture tags,
flow logs to the immutable bucket (Parquet `ALL`), PHI+sovereign passing,
scoped flow-log IAM policy, and **expect_failures** for PHI-not-sovereign,
unapproved/malformed regions, CIDR overlap, and non-RFC1918 CIDRs.

## Notes

- Shared module: declares **no provider block and no backend**; the caller
  supplies both. The `.tftest.hcl` files add a test-only provider with
  credential-checking disabled so plan-only tests run offline.
- Flow logs are **discretionary** (`flow_log_destination` defaults to `null`)
  so the module can plan offline; in production point it at the immutable
  Log Archive bucket to satisfy Pillars 5 & 8.
- CIDR validation uses a small, readable expression (`cidrhost` + anchored
  regex on the network address) rather than a fragile single regex — it accepts
  exactly `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` public-private
  ranges with prefix `/16–/28` and rejects everything else.