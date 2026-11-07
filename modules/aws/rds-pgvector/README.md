# aws/rds-pgvector

Creates an **Aurora PostgreSQL cluster with the `pgvector` extension** (hybrid
vector + relational store for agentic RAG) plus an **RDS Proxy** for connection
pooling. Used by `environments/*/*/data/` and `environments/*/*/ai/`
terraservices.

## Why pgvector + RDS Proxy for RAG

Agentic RAG workloads make many short-lived DB connections (one query → one
vector search → one response). Aurora PostgreSQL + `pgvector` stores both the
vector embeddings and relational metadata in one place (no dual-DB sync), and
**RDS Proxy** pools those connections so the database isn't overwhelmed.
Tuning parameters (`shared_preload_libraries`, `pgvector.index_type`,
`autovacuum`) are applied via a custom parameter group.

## Compliance posture

Compliant **by default** — refuses non-compliant inputs at `tofu plan`:

| Control | Setting | How it's enforced | Pillar |
|---|---|---|---|
| Encryption at rest | KMS CMK, `storage_encrypted = true` | caller-provided `kms_key_arn` + validation | 1 |
| Transmission | RDS Proxy `require_tls = true` | direct resource setting | 1 |
| Least privilege | IAM DB auth, proxy reads only its secret | `iam_database_authentication_enabled`, scoped proxy policy | 2 |
| Network isolation | private subnets only, no `0.0.0.0/0` ingress | `network.subnet_ids`, scoped SG rule | 3 |
| High availability | Aurora multi-AZ, `replica_count ≥ 1` | validation + resource wiring | 4 |
| Observability | detailed 1-min monitoring, Performance Insights, log exports | always-on (Pillar 5 MUST) | 5 |
| Backup/DR | retention ≥ 30, deletion protection, prod keeps final snapshot | lifecycle preconditions | 6 |
| DR (opt-in) | cross-region Aurora Global Cluster to a 2nd approved region | `backup.cross_region_replica`, preconditions | 6 |
| Residency | `phi` ⇒ `sovereign_only = true` | lifecycle precondition | 7 |
| Auditability | tags copied to snapshots, `postgresql` log export | `copy_tags_to_snapshot` | 8 |
| FinOps | Aurora **Serverless** in dev/test, provisioned in prod | `engine_mode` local | 10 |

## Usage

```hcl
module "pgvector" {
  source = "git::https://github.com/anestoa/infrastructure.git//modules/aws/rds-pgvector?ref=v1.0.0"

  environment = "prod"
  name        = "core-rag"
  region      = "us-east-1"
  kms_key_arn = module.kms.key_arn

  # Secrets Manager — never commit a real password.
  secret_arn      = data.aws_secretsmanager_secret.db.arn
  master_password = data.aws_secretsmanager_secret_version.db.secret_string

  network = {
    vpc_id        = module.vpc.vpc_id
    subnet_ids    = module.vpc.subnet_ids["data-*"]
    private_only  = true
    allowed_cidrs = ["10.40.0.0/16"]
  }

  high_availability = { replica_count = 2 }
  # Cross-region DR (opt-in, Pillar 6) — offsite recovery to a 2nd approved region.
  backup = {
    retention_days        = 35
    cross_region_replica  = true
    replica_region        = "us-west-2"
  }

  pgvector = {
    vector_dimensions = 1536
    index_type        = "hnsw"
  }

  data_classification = "phi"
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }
  cost_controls = {
    instance_class = "db.r7g.large"
    cost_center    = "platform"
    project_code   = "core"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `environment` | string | *(required)* | dev/test/staging/prod/commercial. |
| `name` | string | *(required)* | Cluster name prefix + tags. |
| `kms_key_arn` | string | *(required)* | CMK ARN for encryption at rest. |
| `secret_arn` | string | *(required)* | Secrets Manager ARN for DB creds (proxy auth). |
| `pgvector` | object | defaults | `{ enabled, vector_dimensions, index_type, connection_pool_max, enable_parallel_query }`. |
| `allowed_regions` | list(string) | 4 approved | Region allowlist (Pillar 4 — High Availability & Region Control). |
| `region` | string | *(required)* | Target region; must be in `allowed_regions`. |
| `high_availability` | object | `{ replica_count = 1 }` | Aurora replica count. |
| `backup` | object | defaults | `{ retention_days ≥ 30, deletion_protection, skip_final_snapshot, cross_region_replica, replica_region }`. |
| `network` | object | *(required)* | `{ vpc_id, subnet_ids, private_only, allowed_cidrs }`. |
| `observability` | object | defaults | `{ log_group_name, log_retention_days, alarm_topic_arn, detailed_monitoring }`. |
| `iam` | object | `{}` | `{ role_name_prefix, permissions_boundary_arn }`. |
| `data_classification` | string | `internal` | internal/pii/phi/financial/cardholder. |
| `data_residency` | object | `{}` | `sovereign_only`, `jurisdiction`, etc. |
| `master_password` | string | `null` | Sensitive; source from Secrets Manager. |
| `master_username` | string | `appuser` | Master DB user. |
| `cost_controls` | object | — | `instance_class`, `cost_center`, `project_code`. |
| `default_tags` | map(string) | `{}` | Base tags merged onto every resource. |

## Outputs

| Name | Description |
|---|---|
| `cluster_id` | Aurora cluster identifier. |
| `cluster_arn` | Aurora cluster ARN. |
| `cluster_endpoint` | Writer endpoint (DNS). |
| `cluster_reader_endpoint` | Reader endpoint (DNS). |
| `proxy_endpoint` | RDS Proxy endpoint. |
| `security_group_id` | Cluster security group ID. |
| `engine_mode` | `serverless` (dev/test) or `provisioned` (prod/staging). |
| `compliance_controls` | Machine-readable compliance state for OPA/drift. |

## Tests

```bash
cd modules/aws/rds-pgvector
tofu fmt -check
tofu validate
tofu test tests/
```

Assertions cover: KMS encryption, deletion protection, retention ≥ 30,
serverless-in-dev / provisioned-in-prod, proxy TLS, multi-AZ, enhanced
monitoring, tags, and **expect_failures** for PHI-not-sovereign, unapproved
region, and short retention.

## Notes

- Shared module: declares **no provider block and no backend**.
- **Credentials**: the module never generates a password. `master_password`
  comes from Secrets Manager in the calling terraservice; `secret_arn` drives
  the RDS Proxy `SECRETS` auth. This keeps secrets out of state.
- Checkov skips are all documented inline with justification (backup-plan and
  static-resolution false positives); the controls are enforced by preconditions.
- For dev/test, the engine is **Aurora Serverless** to keep cost near zero
  (Pillar 10 — FinOps & Cost Controls); prod uses provisioned `db.r7g.large` by default.

### Offsite DR location

Cross-region snapshots/DR go to a **second approved AWS region** (e.g.
`us-east-1` → `us-west-2`) — **not** the Log Archive bucket. The Log Archive is
an immutable *audit* store (Object Lock COMPLIANCE, Pillar 8); a DR replica is a
*recoverable* copy. Mixing them would make the DR copy hard to restore and the
audit store hard to treat as append-only. This mirrors the industry-standard
separation of "audit trail" vs "recoverable backup."

### Snapshot deletion — least privilege

`copy_tags_to_snapshot = true` copies `SnapshotGuard = "immutable"` (plus
`DataClassification` / `Jurisdiction`) onto every snapshot. Enforcement:
- **OPA** (in `policies/rds-pgvector.rego`) denies any IAM policy that grants
  `rds:DeleteDBSnapshot` / `rds:DeleteDBClusterSnapshot` on a `"*"` resource.
- **Recommended IAM split**: only a dedicated ops/DR role may
  `rds:DeleteDBSnapshot` (and only on `arn:aws:rds:...:snapshot:*-pgvector-*`
  scoped to the backup-vault flow). Regular developers get **no**
  snapshot-delete grant. This is the "no regular dev can delete a snapshot"
  guard, enforced at the plan-time (OPA) and resource-level (tag) layers.

## Examples

- `examples/basic-usage/` — a compliant pgvector cluster wired to a Secrets
  Manager credential and private subnets.