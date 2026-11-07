# GenAI Agentic Runtime — Module Design

> Managed-service modules for building compliant agentic AI runtimes on AWS.
> Tier 1 modules target the foundational triad: **vector store (memory)**,
> **model inference (reasoning)**, and **private development (training)**.
>
> **Status:** Design phase. No OpenTofu code written yet.

---

## 1. Architecture Overview

### The Agentic Runtime Stack

```
┌──────────────────────────────────────────────────────────────┐
│                   Agent Orchestration                          │
│  LangChain / LangGraph / CrewAI / AWS Bedrock Agents          │
│  ── Application code, not infrastructure ──                   │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│              ┌──────────────────────────┐                     │
│              │     Managed Services     │ ◄── OpenTofu modules │
│              │  (Tier 1 — this design)  │                     │
│              │                          │                     │
│  Memory/RAG  │  Inference     │ Dev/Train                     │
│  ┌────────┐  │  ┌──────────┐  │ ┌──────────┐                 │
│  │OpenSearch│  │  Bedrock   │  │ SageMaker │                 │
│  │Serverless│  │  Endpoint  │  │  Domain   │                 │
│  │(vectors) │  │ ┌────────┐ │  │ (Studio)  │                 │
│  │┌────────┐│  │ │Guardrail│ │  └──────────┘                 │
│  ││pgvector││  │ └────────┘ │                                │
│  ││ (RDS)  ││  └──────────┘                                  │
│  │└────────┘│                                                │
│  └──────────┘                                                 │
│                                                               │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│              ┌──────────────────────────┐                     │
│              │ Foundational Infrastructure │ ◄── Existing     │
│              │ VPC, KMS, IAM, Transit GW  │     modules      │
│              └──────────────────────────┘                     │
└──────────────────────────────────────────────────────────────┘
```

### How agents use these services

```
User Query
    │
    ▼
Bedrock Agent (orchestrator) ─── uses Bedrock Endpoint for LLM reasoning
    │
    ├──→ Bedrock Guardrail (content safety, PII redaction, prompt injection)
    │
    ├──→ OpenSearch Collection (vector search — RAG context retrieval)
    │
    ├──→ pgvector RDS (hybrid query — vector + relational filters)
    │
    └──→ SageMaker Domain (training data pipeline, model fine-tuning)
            │
            └──→ S3 Data Lake (encrypted, versioned, Object Lock)
```

All traffic flows through VPC Endpoints or Transit Gateway — no public internet.

---

## 2. Module Catalog

### 2.1 `opensearch-collection`

**AWS resource:** `aws_opensearchserverless_collection` + `aws_opensearchserverless_lifecycle_policy`
**Used by:** `environments/*/*/data/` and `environments/*/*/ai/` terraservices
**Purpose:** Vector database for RAG pipelines. Primary agent memory store.

#### Variables

```hcl
variable "kms_key_arn" {
  description = "CMK ARN for encryption at rest."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "Must be a valid KMS key ARN."
  }
}

variable "collection" {
  description = "OpenSearch Serverless collection configuration"
  type = object({
    name             = string
    type             = optional(string, "VECTORSEARCH")
    vector_dimension = optional(number, 1536)       # Matches ada-002 / text-embedding-3-large
    description      = optional(string, null)
  })
  nullable = false
}

variable "network" {
  description = "Network placement — VPC endpoint for private access"
  type = object({
    vpc_id             = string
    vpc_endpoint_ids   = list(string)
    private_only       = optional(bool, true)
  })
  nullable = false
}

variable "lifecycle" {
  description = "Snapshot and retention policy"
  type = object({
    retention_days      = optional(number, 30)
    snapshot_hour       = optional(number, 3)       # UTC hour for automatic snapshots
    deletion_protection = optional(bool, true)
  })
  nullable = false
  validation {
    condition     = var.lifecycle.retention_days >= 30
    error_message = "Minimum retention is 30 days."
  }
}

variable "observability" { /* standard pillar */ }
variable "iam" { /* standard pillar — scoped to opensearch:Search, opensearch:Ingest */ }
variable "data_classification" { /* standard pillar */ }
variable "data_residency" { /* standard pillar */ }
variable "environment" { /* standard pillar */ }
variable "cost_controls" { /* standard pillar — storage + query volume budgets */ }
```

#### Key resource wiring

```hcl
resource "aws_opensearchserverless_collection" "this" {
  name        = local.collection_name
  type        = var.collection.type
  description = var.collection.description != null ? var.collection.description : "Vector store for ${var.environment} RAG pipelines"

  security_config {
    kms_key_arn = var.kms_key_arn
  }

  # VPC endpoint association for private access
  # Endpoint must be of type OPENSEARCH_SERVERLESS
  vpc_options {
    vpc_endpoint_id = element(var.network.vpc_endpoint_ids, 0)
  }

  tags = local.standard_tags
}

resource "aws_opensearchserverless_lifecycle_policy" "this" {
  name        = "${local.collection_name}-lifecycle"
  description = "Retention and snapshot policy"
  policy_json = jsonencode({
    snapshot = {
      retention_days = var.lifecycle.retention_days
      schedule_hour  = var.lifecycle.snapshot_hour
    }
    deletion_protection = var.lifecycle.deletion_protection
  })

  collection = aws_opensearchserverless_collection.this.name
}
```

#### Outputs

```hcl
output "collection_endpoint" {
  description = "OpenSearch endpoint URL for the collection"
  value       = aws_opensearchserverless_collection.this.collection_endpoint
}

output "collection_id" {
  description = "OpenSearch collection ID"
  value       = aws_opensearchserverless_collection.this.id
}

output "compliance_controls" {
  description = "Compliance state for OPA evaluation"
  value = {
    environment      = var.environment
    encryption       = var.kms_key_arn != null
    private_network  = var.network.private_only
    retention_days   = var.lifecycle.retention_days
    deletion_protect = var.lifecycle.deletion_protection
    data_class       = var.data_classification
  }
}
```

#### Compliance test coverage

| Test | Assertion |
|------|-----------|
| `defaults.tftest.hcl` | KMS key set, deletion_protection=true, retention_days >= 30 |
| `prod.tftest.hcl` | Prod-grade inputs, multi-AZ (N/A — serverless), full logging |
| `compliance.tftest.hcl` | `expect_failures` on missing KMS, short retention, no VPC endpoint |

---

### 2.2 `bedrock-endpoint`

**AWS resource:** `aws_bedrock_custom_model` + `aws_bedrock_model_inference_profile`
**Used by:** `environments/*/*/ai/` terraservices
**Purpose:** Managed foundation model access for agentic inference.

#### Variables

```hcl
variable "kms_key_arn" {
  description = "CMK ARN for model artifact encryption in S3."
  type        = string
  nullable    = false
}

variable "inference_profile" {
  description = "Model selection and inference parameters"
  type = object({
    model_name              = string
    model_version           = optional(string, null)
    max_tokens              = optional(number, 4096)
    temperature             = optional(number, 0.7)
    top_p                   = optional(number, 0.9)
    enable_invocation_logs  = optional(bool, true)
    guardrail_id            = optional(string, null)
    endpoint_type           = optional(string, "STANDARD")  # STANDARD | ELASTIC | STREAMING
    region_priority         = optional(list(string), [])    # Multi-region fallback order
  })
  nullable = false
}

variable "network" {
  description = "Network placement — VPC endpoint for Bedrock access"
  type = object({
    vpc_id             = string
    vpc_endpoint_ids   = list(string)
  })
  nullable = false
  # Bedrock accessed via com.amazonaws.<region>.bedrock VPC endpoint
}

variable "observability" { /* standard pillar — invocation logging is mandatory */ }
variable "iam" { /* standard pillar — scoped to bedrock:InvokeModel */ }
variable "data_classification" { /* standard pillar */ }
variable "data_residency" { /* standard pillar — critical for Bedrock data processing */ }
variable "environment" { /* standard pillar */ }
variable "cost_controls" { /* standard pillar — per-invocation budget alarms */ }
```

#### Key resource wiring

```hcl
resource "aws_bedrock_model_inference_profile" "this" {
  model_selection = {
    model_name    = var.inference_profile.model_name
    model_version = var.inference_profile.model_version
  }

  endpoint_type = var.inference_profile.endpoint_type
  max_tokens    = var.inference_profile.max_tokens
  temperature   = var.inference_profile.temperature
  top_p         = var.inference_profile.top_p

  # Guardrail reference — content safety applied to every invocation
  guardrail = var.inference_profile.guardrail_id != null ? {
    guardrail_id = var.inference_profile.guardrail_id
    mode         = "ENFORCED"
  } : null

  # Invocation logging — compliance requirement for HIPAA
  invocation_logging_configuration {
    log_group_name     = local.log_group_name
    log_retention_days = var.observability.log_retention_days
    log_s3_bucket_arn  = var.observability.s3_log_bucket_arn
  }

  # VPC endpoint for private access
  vpc_config {
    vpc_endpoint_id = element(var.network.vpc_endpoint_ids, 0)
  }

  tags = local.standard_tags
}
```

#### Design notes

- **Logging is mandatory** when `data_classification` is `phi`, `pii`, or `financial`.
  OPA rule should fail if invocation logging is disabled for classified data.
- **Guardrails are optional but warned** — OPA should emit a warning if no guardrail
  is assigned in prod environments.
- **Multi-region fallback** only allowed when `data_residency.allow_cross_border_replication`
  is true and has an approval ref. For PHI, cross-region fallback is denied at the OPA level.

---

### 2.3 `bedrock-guardrail`

**AWS resource:** `aws_bedrock_guardrail`
**Used by:** `environments/*/*/ai/` terraservices — companion to `bedrock-endpoint`
**Purpose:** Content safety, PII redaction, prompt injection defense.

#### Variables

```hcl
variable "guardrail_config" {
  description = "Content safety guardrail configuration"
  type = object({
    name                     = string
    description              = optional(string, null)
    blocked_topics           = optional(list(string), [])
    # PII handling
    pii_redaction            = optional(string, "ANONYMIZE")  # ANONYMIZE | REJECT | OFF
    pii_entities             = optional(list(string), ["SSN", "EMAIL", "PHONE", "CREDIT_DEBIT_NUMBER", "HEALTH_CARD"])
    # Content filters by category and threshold (NONE | LOW | MEDIUM | HIGH)
    filters = optional(object({
      hate_speech      = optional(string, "HIGH")
      sexual_content   = optional(string, "NONE")
      violence         = optional(string, "MEDIUM")
      misconduct       = optional(string, "HIGH")
      prompt_injection = optional(string, "HIGH")
      profanity        = optional(string, "MEDIUM")
    }), {})
    # Context grounding — prevent hallucination by grounding in provided context
    grounding = optional(object({
      enabled            = optional(bool, false)
      source             = optional(string, null)    # S3 URI or OpenSearch index
      min_grounding_score = optional(number, 0.7)
    }), {})
  })
  nullable = false
}

# Guardrails don't need kms_key_arn, network, or backup —
# they define policies, not data storage.

variable "iam" { /* standard pillar — management vs reference roles */ }
variable "environment" { /* standard pillar */ }
variable "data_classification" { /* standard pillar — guardrail content may itself be sensitive */ }
```

#### Key resource wiring

```hcl
resource "aws_bedrock_guardrail" "this" {
  name        = var.guardrail_config.name
  description = var.guardrail_config.description != null
    ? var.guardrail_config.description
    : "Regulatory guardrail for ${var.environment} agentic workloads"

  content_policy_config {
    filters = compact([
      { type = "HATE_SPEECH", threshold = var.guardrail_config.filters.hate_speech },
      { type = "SEXUAL",      threshold = var.guardrail_config.filters.sexual_content },
      { type = "VIOLENCE",    threshold = var.guardrail_config.filters.violence },
      { type = "MISCONDUCT",  threshold = var.guardrail_config.filters.misconduct },
      { type = "PROMPT_INJECTION", threshold = var.guardrail_config.filters.prompt_injection },
      { type = "PROFANITY",   threshold = var.guardrail_config.filters.profanity },
    ])
  }

  # Topic blocking for regulated domains
  # Topic definitions live in: policies/topics/<topic-name>.json
  topic_policy_config {
    topics = [
      for topic in var.guardrail_config.blocked_topics : {
        name     = topic
        definition = jsondecode(file("${path.module}/policies/topics/${lower(replace(topic, " ", "_"))}.json"))
      }
    ]
  }

  pii_policy_config {
    redact = var.guardrail_config.pii_redaction
    entities = var.guardrail_config.pii_entities
  }

  contextual_grounding_policy_config {
    enabled             = var.guardrail_config.grounding.enabled
    source              = var.guardrail_config.grounding.source
    min_grounding_score = var.guardrail_config.grounding.min_grounding_score
  }

  tags = local.standard_tags
}
```

#### OPA enforcement

- **Fail** if `data_classification = "phi"` and no guardrail is referenced by any
  `bedrock-endpoint` in the same terraservice.
- **Fail** if `guardrail_config.pii_redaction = "OFF"` when `data_classification`
  contains PII or PHI.
- **Warn** if `grounding.enabled = false` in prod — ungrounded model responses
  increase hallucination risk in regulated contexts.

---

### 2.4 `sagemaker-domain`

**AWS resource:** `aws_sagemaker_domain` + `aws_sagemaker_user_profile`
**Used by:** `environments/*/*/ai/` terraservices
**Purpose:** Private AI development environment in VPC-only mode.

#### Variables

```hcl
variable "kms_key_arn" { /* standard pillar */ }

variable "sagemaker_domain" {
  description = "SageMaker Domain configuration for private AI development"
  type = object({
    name                  = string
    auth_mode             = optional(string, "IAM")  # IAM | SSO
    default_user_settings = optional(object({
      idle_shutdown_hours        = optional(number, 2)
      auto_shutdown_hours        = optional(number, 8)
      notebook_size_gb           = optional(number, 5)
      kernel_type               = optional(string, "conda_python3")
    }), {})
    studio_config = optional(object({
      enabled       = optional(bool, true)
      idle_timeout  = optional(number, 30)      # minutes
      mlflow_enabled = optional(bool, true)
    }), {})
  })
  nullable = false
}

variable "network" {
  description = "Network placement — VPC-only mode"
  type = object({
    vpc_id              = string
    subnet_ids          = list(string)
    vpc_endpoint_ids    = list(string)
    private_only        = optional(bool, true)
  })
  nullable = false
  # VPC-only mode is enforced — SageMaker domain routes all traffic through
  # VPC endpoints. No internet access.
}

variable "observability" { /* standard pillar */ }
variable "iam" { /* standard pillar — per-user profiles */ }
variable "data_classification" { /* standard pillar */ }
variable "data_residency" { /* standard pillar */ }
variable "environment" { /* standard pillar */ }
variable "cost_controls" { /* standard pillar — compute time budgets, auto-shutdown */ }
```

#### Key resource wiring

```hcl
resource "aws_sagemaker_domain" "this" {
  domain_name = local.sagemaker_name
  auth_mode   = var.sagemaker_domain.auth_mode

  # VPC-only — no internet access for data security
  vpc_config {
    vpc_id         = var.network.vpc_id
    subnet_ids     = var.network.subnet_ids
    vpc_endpoint_ids = var.network.vpc_endpoint_ids
  }

  default_user_settings {
    execution_policy {
      max_runtime_in_seconds  = var.sagemaker_domain.default_user_settings.auto_shutdown_hours * 3600
      max_idle_time_in_seconds = var.sagemaker_domain.default_user_settings.idle_shutdown_hours * 3600
    }
    notebook_storage_config {
      default_storage_size_in_gb = var.sagemaker_domain.default_user_settings.notebook_size_gb
    }
    kernel_config {
      default_kernel = var.sagemaker_domain.default_user_settings.kernel_type
    }
  }

  # Studio for visual AI development
  studio_config {
    enabled         = var.sagemaker_domain.studio_config.enabled
    idle_timeout_in_minutes = var.sagemaker_domain.studio_config.idle_timeout
    mlflow_config {
      enabled = var.sagemaker_domain.studio_config.mlflow_enabled
    }
  }

  tags = local.standard_tags
}
```

#### Domain vs user profiles

The module creates the **domain** (shared infrastructure). User profiles are either:
- Created ad-hoc via SageMaker SDK (for teams with many data scientists)
- Declared in the terraservice if there are fixed, known users

User profiles are **not** a one-resource-per-module concern — a `sagemaker-domain` module
can optionally include `aws_sagemaker_user_profile` resources for known users, controlled
by a boolean flag.

---

### 2.5 `rds-pgvector`

**AWS resource:** `aws_rds_cluster` (Aurora PostgreSQL) + custom parameter group
**Used by:** `environments/*/*/data/` terraservices
**Purpose:** Hybrid vector + relational store for agentic RAG.

#### Variables

```hcl
variable "kms_key_arn" { /* standard pillar */ }

variable "pgvector" {
  description = "pgvector extension configuration"
  type = object({
    enabled                   = optional(bool, true)
    vector_dimensions         = optional(number, 1536)
    index_type                = optional(string, "hnsw")        # hnsw | ivfflat
    index_maintenance_window  = optional(string, "sun:03:00-sun:05:00")
    connection_pool_max       = optional(number, 100)
    enable_parallel_query     = optional(bool, true)
  })
  nullable = false
}

variable "high_availability" { /* standard pillar — multi-AZ, replica count */ }
variable "backup" { /* standard pillar — retention, deletion protection */ }
variable "network" { /* standard pillar — private subnets only */ }
variable "observability" { /* standard pillar — Enhanced Monitoring, Perf Insights */ }
variable "iam" { /* standard pillar — scoped RDS roles */ }
variable "data_classification" { /* standard pillar */ }
variable "data_residency" { /* standard pillar */ }
variable "environment" { /* standard pillar */ }
variable "cost_controls" { /* standard pillar — Aurora Serverless for dev/test */ }
```

#### Key resource wiring

```hcl
# Custom parameter group with pgvector tuning
resource "aws_rds_cluster_parameter_group" "pgvector" {
  family = "aurora-postgresql16"

  parameters = {
    # pgvector tuning
    "shared_preload_libraries" = "pgvector"
    "pgvector.index_type"     = var.pgvector.index_type
    "pgvector.dimensions"     = toString(var.pgvector.vector_dimensions)

    # Connection pooling for RAG workloads
    "max_connections"             = toString(var.pgvector.connection_pool_max)
    "parallel_query"              = var.pgvector.enable_parallel_query ? "1" : "0"

    # Auto-vacuum tuning for vector tables
    "autovacuum_vacuum_scale_factor"  = "0.01"
    "autovacuum_analyze_scale_factor" = "0.005"
  }
}

resource "aws_rds_cluster" "this" {
  cluster_identifier  = local.cluster_name
  engine              = "aurora-postgresql"
  engine_version      = "16.2"
  engine_mode         = var.environment == "dev" ? "serverless" : "provisioned"

  # Multi-AZ default (Aurora is always multi-replica by design)
  # Replica count from high_availability config

  # KMS encryption
  storage_encrypted = true
  kms_key_id       = var.kms_key_arn

  # Network — private subnets only
  vpc_security_group_ids = [aws_security_group.this.id]
  db_subnet_group_name   = aws_db_subnet_group.this.name

  # Backup and deletion protection
  backup_retention_period        = var.backup.retention_days
  deletion_protection            = var.backup.deletion_protection
  skip_final_snapshot            = var.backup.skip_final_snapshot == true && var.environment == "prod" ? false : var.backup.skip_final_snapshot

  # Parameter group with pgvector
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.pgvector.name

  tags = local.standard_tags
}
```

#### Connection pooling for RAG

Agentic RAG workloads create many short-lived connections (one query → one vector search →
one response). RDS Proxy is configured as a connection pool to handle this:

```hcl
resource "aws_db_proxy" "this" {
  name                   = "${local.cluster_name}-proxy"
  debug_logging          = var.observability.detailed_monitoring
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 600    # seconds
  max_idle_connections   = var.pgvector.connection_pool_max
  require_tls            = true

  # VPC placement
  vpc_subnet_ids = var.network.subnet_ids
}
```

---

## 3. Module Consumption Pattern

In a workload's `ai/` or `data/` terraservice, modules are composed:

```hcl
# environments/production/platform/ai/main.tf
module "opensearch_rag" {
  source = "../../../modules/opensearch-collection"

  kms_key_arn      = var.kms_key_arn
  network          = var.network
  iam              = var.iam
  observability    = var.observability
  collection       = { name = "platform-prod-rag", vector_dimension = 1536 }
  lifecycle        = { retention_days = 30, deletion_protection = true }
  data_classification = var.data_classification
  data_residency     = var.data_residency
  environment        = var.environment
  cost_controls      = var.cost_controls
}

module "bedrock_guardrail" {
  source = "../../../modules/bedrock-guardrail"

  guardrail_config = {
    name           = "platform-prod-guardrail"
    pii_redaction  = "ANONYMIZE"
    filters        = { hate_speech = "HIGH", prompt_injection = "HIGH" }
    blocked_topics = ["FINANCIAL_ADVICE", "MEDICAL_DIAGNOSIS"]
  }
  environment        = var.environment
  data_classification = var.data_classification
}

module "bedrock_llm" {
  source = "../../../modules/bedrock-endpoint"

  kms_key_arn       = var.kms_key_arn
  network           = var.network
  iam               = var.iam
  observability     = var.observability
  inference_profile = {
    model_name    = "anthropic.claude-sonnet-5-1"
    guardrail_id  = module.bedrock_guardrail.guardrail_id
  }
  data_classification = var.data_classification
  data_residency     = var.data_residency
  environment        = var.environment
  cost_controls      = var.cost_controls
}
```

### Apply order within a terraservice

```
1. bedrock-guardrail     (no deps on other modules)
2. bedrock-endpoint      (depends on: guardrail_id)
3. opensearch-collection (no deps on other modules — just IAM, KMS, VPC)
```

These are consumed by `ai/` terraservice. The `data/` terraservice consumes
`opensearch-collection` and `rds-pgvector` independently (no cross-dependency).

---

## 4. Compliance Cross-Cuts

### OPA rules (one or more per module)

| Rule | Module | Effect |
|------|--------|--------|
| `opensearch_no_kms` | opensearch-collection | Fail if `kms_key_arn` is null |
| `opensearch_no_vpc_endpoint` | opensearch-collection | Fail if no VPC endpoint configured |
| `opensearch_short_retention` | opensearch-collection | Fail if `retention_days < 30` |
| `bedrock_no_guardrail_prod` | bedrock-endpoint | Warn if `guardrail_id` is null in prod |
| `bedrock_invocation_logging_phi` | bedrock-endpoint | Fail if PHI and invocation logging disabled |
| `bedrock_phi_cross_region` | bedrock-endpoint | Fail if PHI and multi-region fallback enabled |
| `guardrail_pii_off_for_phi` | bedrock-guardrail | Fail if PHI and PII redaction is OFF |
| `sagemaker_vpc_only` | sagemaker-domain | Fail if `private_only = false` |
| `sagemaker_no_shutdown_prod` | sagemaker-domain | Fail if prod and no auto-shutdown |
| `pgvector_prod_snapshot` | rds-pgvector | Fail if prod and `skip_final_snapshot = true` |

### Checkov rules

Every module should pass these existing checks (from CLAUDE.md pillar templates):

| Module | CKV check |
|--------|-----------|
| opensearch-collection | CKV_AWS_33 (Logging), CKV_AWS_158 (KMS) |
| bedrock-endpoint | CKV_AWS_33 (Logging), CKV_AWS_149 (Monitoring) |
| sagemaker-domain | CKV_AWS_33 (Logging), CKV_AWS_68 (Subnet placement) |
| rds-pgvector | CKV_AWS_33 (Logging), CKV_AWS_28 (Deletion protection), CKV_AWS_157 (Backup) |

---

## 5. Implementation Notes

### Module structure (per existing convention)

```
modules/<name>/
├── main.tf                  # Resource definitions
├── variables.tf             # All pillar variables + module-specific vars
├── outputs.tf               # Module outputs (endpoints, IDs, compliance_controls)
├── locals.tf                # Computed values, naming, tags
├── data.tf                  # Data sources only (if any)
├── versions.tf              # Provider requirements + tofu version
├── README.md                # Purpose, usage, variables, outputs, pillar compliance
├── policies/                # OPA rules scoped to this module
│   └── <module-name>.rego
└── tests/
    ├── defaults.tftest.hcl      # Plan with defaults
    ├── prod.tftest.hcl          # Plan with prod-grade inputs
    ├── compliance.tftest.hcl    # expect_failures on compliance gates
    └── fixtures/                # Test-only .tf files
```

### HCL considerations

- **OpenSearch Serverless** resources use `aws_opensearchserverless_*` — available in
  AWS provider v5.x+. Pinned in `versions.tf`.
- **Bedrock Guardrail** uses `aws_bedrock_guardrail` — requires AWS provider version
  that supports the resource (v5.80+).
- **Bedrock inference profiles** use `aws_bedrock_model_inference_profile` — newer
  resource, verify provider support.
- **SageMaker Domain** uses `aws_sagemaker_domain` + `aws_sagemaker_user_profile` —
  well-established resources.
- **RDS pgvector** builds on standard `aws_rds_cluster` — the custom parameter group
  is the module's primary value add.

### OpenTofu-specific notes

- `can(regex(...))` for variable validation (Terraform compatibility note)
- `tosupported()` is not available in Tofu — use `jsonencode()` + `jsondecode()`
  for complex type handling
- File-based resources (like guardrail topic definitions) use `file()` function

---

## 6. Skill Integration

This document is referenced by skills:

| Skill | Reads this document for |
|-------|------------------------|
| `/create-module` | Module variable templates, compliance interface patterns |
| `/create-workload` | Full module consumption in ai/ and data/ terraservices |
| (future) `/add-genai-module` | Full module generation — copies patterns from this document |