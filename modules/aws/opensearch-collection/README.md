# aws/opensearch-collection

Creates an **OpenSearch Serverless vector collection** (RAG / vector search) that is
**always** encrypted with a caller-provided KMS CMK and **always** private via its own
OpenSearch Serverless VPC endpoint. Used by `environments/*/*/data/` and
`environments/*/*/ai/` terraservices.

## Why this module is opinionated

OpenSearch Serverless has **no native deletion-protection toggle** and a collection can be
publicly reachable if misconfigured. Rather than expose those as options a developer might get
wrong, this module makes the compliant states the *only* states:

- A private VPC endpoint **is always provisioned** — there is no `public` option and no toggle.
- The network policy is **always** `AllowFromPublic: false`, sourced only to that endpoint.
- Encryption **always** uses a caller-provided CMK via an encryption security policy — never an
  AWS-owned key.
- The data access policy **always** scopes read/write to the exact IAM principals you pass.
- Retention is **always** ≥ 30 days via a data lifecycle policy.

## Compliance posture

Compliant **by default** — refuses non-compliant inputs at `tofu plan`:

| Control | Setting | How it's enforced | Pillar |
|---|---|---|---|
| Encryption at rest | caller-provided CMK | encryption security policy bound to the collection name | 1 |
| No AWS-owned key | `AWSOwnedKey: false` | encryption policy JSON | 1 |
| Private-only | private AOSS VPC endpoint, `AllowFromPublic: false` | always provisioned (no toggle) | 3 |
| Least privilege | data access policy scoped to caller principals | `aoss:ReadDocument`/`aoss:WriteDocument` only | 2 |
| High availability | `standby_replicas = ENABLED` by default | resource setting | 4 |
| Observability | CloudTrail data-plane audit + default health alarm | `alarm_topic_arn` wiring | 5 |
| Retention | lifecycle policy ≥ 30 days | validation + policy JSON | 6 |
| Residency | `phi` ⇒ `sovereign_only = true` | lifecycle precondition | 7 |
| FinOps | cost tags, budget wiring | `cost_controls` | 10 |

## Usage

```hcl
module "rag_store" {
  source = "git::https://github.com/anestoa/infrastructure.git//modules/aws/opensearch-collection?ref=v1.0.0"

  environment = "prod"
  name        = "core-rag"
  region      = "us-east-1"
  kms_key_arn = module.kms.key_arn

  network = {
    vpc_id             = module.vpc.id
    subnet_ids         = module.vpc.subnets["data-*"]
    security_group_ids = [module.vpc.data_sg.id]
  }

  iam = {
    principal_arns = ["arn:aws:iam::123456789012:role/app-service"]
  }

  collection = {
    type             = "VECTORSEARCH"
    vector_dimension = 1536
  }

  data_classification = "phi"
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }
  cost_controls = {
    cost_center  = "platform"
    project_code = "core"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `environment` | string | *(required)* | dev/test/staging/prod/commercial. |
| `name` | string | *(required)* | Prefix for resource names + tags. |
| `kms_key_arn` | string | *(required)* | CMK ARN for encryption at rest. |
| `network` | object | *(required)* | `{ vpc_id, subnet_ids ≥ 2, security_group_ids ≥ 1 }` — always private. |
| `iam` | object | *(required)* | `{ principal_arns ≥ 1, permissions_boundary_arn }`. |
| `collection` | object | defaults | `{ name, type=VECTORSEARCH, vector_dimension=1536, description }`. |
| `allowed_regions` | list(string) | 4 approved | Region allowlist (Pillar 4). |
| `region` | string | *(required)* | Target region; must be in `allowed_regions`. |
| `high_availability` | object | `{ standby_replicas = ENABLED }` | Multi-AZ durability. |
| `backup` | object | `{ retention_days = 30 }` | Data lifecycle retention. |
| `observability` | object | `{}` | `alarm_topic_arn`, `log_retention_days`. |
| `data_classification` | string | `internal` | internal/pii/phi/financial/cardholder. |
| `data_residency` | object | `{}` | `sovereign_only`, `jurisdiction`, etc. |
| `cost_controls` | object | `{}` | `budget_amount`, `budget_email`, `cost_center`, `project_code`. |
| `default_tags` | map(string) | `{}` | Base tags merged onto every tagged resource. |

## Outputs

| Name | Description |
|---|---|
| `collection_id` | OpenSearch Serverless collection ID. |
| `collection_arn` | OpenSearch Serverless collection ARN. |
| `collection_endpoint` | OpenSearch endpoint URL for the collection. |
| `collection_dashboard_endpoint` | OpenSearch Dashboards endpoint. |
| `vpc_endpoint_id` | The private AOSS VPC endpoint ID. |
| `compliance_controls` | Machine-readable compliance state for OPA/drift. |

## Tests

```bash
cd modules/aws/opensearch-collection
tofu fmt -check
tofu validate
tofu test tests/
```

Assertions cover: VECTORSEARCH type, always-on private VPC endpoint, network policy
`AllowFromPublic: false`, encryption policy CMK + no AWS-owned key, retention ≥ 30,
standby replicas, least-privilege access policy, and **expect_failures** for an unapproved
region, PHI-not-sovereign, short retention, and single-AZ endpoints.

## Notes

- Shared module: declares **no provider block and no backend**.
- **No public option exists.** Public access is deliberately impossible through this module;
  a genuine need is handled as an approved exception outside the module.
- **AOSS VPC endpoints** (`aws_opensearchserverless_vpc_endpoint`) are distinct from the
  interface endpoints in the `vpc-endpoint` module; that module covers standard
  `aws_vpc_endpoint` services, not OpenSearch Serverless.
- The `aws_opensearchserverless_vpc_endpoint` resource does not expose a `tags` attribute;
  attribution tags live on the collection and policy resources.
- **Observability:** data-plane audit for AOSS is CloudTrail-based (platform-level). The module
  additionally wires an optional default CloudWatch alarm to `alarm_topic_arn`.

## Examples

- `examples/basic-usage/` — a compliant private vector collection wired to a KMS key, VPC, and an
  app IAM role.