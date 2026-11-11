# Data — Aurora pgvector + OpenSearch Serverless

> Part of `environments/production/platform/`. Apply third (after `network/`).
> Reads remote state from `iam/` and `network/`.

## Purpose

Creates the data stores for the GenAI agentic runtime:

| Resource | Module | Purpose |
|----------|--------|---------|
| Aurora PostgreSQL + pgvector | `rds-pgvector` | Hybrid relational + vector storage for agentic RAG |
| OpenSearch Serverless | `opensearch-collection` | Vector search index for document retrieval |

### Dev-specific sizing

| Setting | Value | Why |
|---------|-------|-----|
| Aurora instance | Aurora Serverless v2 (1 ACU min) | Cheapest dev footprint |
| pgvector replicas | 1 | Enough for dev, saves cost vs prod |
| OpenSearch standby | DISABLED | No HA needed in dev |
| Detailed monitoring | false | Saves CloudWatch costs |
| Shutdown hours | Outside business hours | Stops compute overnight (set in compute/) |

## Safety: blast radius

| Change | Blast radius | Why |
|--------|-------------|-----|
| Add a new data store (e.g., ElastiCache) | None | New module, new output — no downstream references until you add them |
| Change pgvector retention | Low | Compute/ai don't read retention values |
| Delete pgvector | **High** | Compute/ai break at plan time — caught by Atlantis |
| Change OpenSearch collection type | Low | Endpoint URL changes, but downstream services should handle it via config |

## Remote state contract

**Reads** from `iam/` and `network/`:
- `iam.app_kms_key_arn` → KMS encryption
- `iam.rds_proxy_role_arn` → RDS Proxy IAM
- `network.vpc_id`, `network.data_subnet_ids` → network placement
- `network.default_security_group_id` → security group

**Exports** to `compute/` and `ai/`:
- `pgvector_endpoint`, `pgvector_reader_endpoint` → DB connection
- `opensearch_collection_endpoint` → vector search endpoint

## Customization points

1. **pgvector dimensions** — Change `vector_dimensions` to match your embedding model (1536 for ada-002, 1024 for Cohere, etc.)
2. **OpenSearch standby** — Set `high_availability.standby_replicas = "ENABLED"` when moving to prod
3. **Backup retention** — Set `backup.retention_days` to 90+ for preprod/prod
4. **Principal ARNs** — Fill in `iam.principal_arns` for OpenSearch after compute/ai roles are known

## Pillar compliance

| Pillar | How it's met |
|--------|-------------|
| 1 — Encryption | KMS CMK for both RDS and OpenSearch |
| 3 — Network Isolation | Private subnets, VPC endpoint (AOSS) |
| 4 — HA | Aurora multi-AZ, OpenSearch standby replicas (opt-in) |
| 5 — Observability | CloudWatch alarms, centralized logging |
| 6 — Backup/DR | Retention ≥ 30, deletion protection, cross-region opt-in |
| 7 — Data Residency | Classification + residency gates |
| 10 — FinOps | Dev-sized instances, cost tags |
