# ─────────────────────────────────────────────────────────────────────────────
# opensearch-collection module — OpenSearch Serverless vector store (Pillars 1-10)
#
# Vector database for RAG pipelines (primary agent memory store). Used by
# environments/*/*/data/ and environments/*/*/ai/ terraservices.
#
# Deliberately opinionated: it is NOT possible to build a public collection or
# one without encryption through this module. The VPC endpoint + encryption
# policy + private network policy are always provisioned; there is no toggle.
# ─────────────────────────────────────────────────────────────────────────────

# Pillar 9 — Change Management & Policy Enforcement (environment gating).
variable "environment" {
  description = "Environment: dev, test, staging, prod, preprod, sandbox, commercial"
  type        = string
  nullable    = false
  validation {
    condition     = contains(["dev", "test", "staging", "prod", "preprod", "sandbox", "commercial"], var.environment)
    error_message = "Must be one of: dev, test, staging, prod, preprod, sandbox, commercial."
  }
}

variable "name" {
  description = "Collection name. Prefixes resource names and tags."
  type        = string
  nullable    = false
}

# ── Pillar 1 — Encryption (caller-provided CMK) ─────────────────────
# Applied via an encryption security policy matched to this collection name.
variable "kms_key_arn" {
  description = "CMK ARN for encryption at rest. Module does NOT create a key."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "Must be a valid KMS key ARN."
  }
}

# ── Collection configuration ────────────────────────────────────────────────
variable "collection" {
  description = "OpenSearch Serverless collection configuration."
  type = object({
    name             = optional(string, null)           # defaults to var.name
    type             = optional(string, "VECTORSEARCH") # VECTORSEARCH | SEARCH
    vector_dimension = optional(number, 1536)           # matches ada-002 / text-embedding-3-large
    description      = optional(string, null)
  })
  nullable = false
  default  = {}
  validation {
    condition     = contains(["VECTORSEARCH", "SEARCH"], var.collection.type)
    error_message = "collection.type must be 'VECTORSEARCH' or 'SEARCH'."
  }
}

# ── Pillar 3 — Network Security & Isolation (private-only, ALWAYS) ───────────
# The module ALWAYS creates a private AOSS VPC endpoint and locks the network
# policy to AllowFromPublic=false. There is no public-access option.
variable "network" {
  description = "Network placement. The module always provisions a private VPC endpoint; public access is impossible."
  type = object({
    vpc_id             = string
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  nullable = false
  # NOTE: subnet (≥2) and security-group (≥1) counts are enforced via lifecycle
  # preconditions on the VPC endpoint (see main.tf) — not variable validations —
  # so `tofu test` expect_failures can attach them to the resource.
}

# ── Pillar 4 — High Availability & Region Control ───────────────────────────
variable "allowed_regions" {
  description = "Approved regions. Rejected at plan time if outside this list."
  type        = list(string)
  nullable    = false
  default     = ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"]
}

variable "region" {
  description = "Target region. Must be in allowed_regions."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^(us-(east|west)-[12]|eu-(west|central)-[12])$", var.region))
    error_message = "Region is not an approved AWS region pattern."
  }
}

variable "high_availability" {
  description = "Standby replicas for multi-AZ durability (Pillar 4)."
  type = object({
    standby_replicas = optional(string, "ENABLED") # ENABLED | DISABLED
  })
  nullable = false
  default  = { standby_replicas = "ENABLED" }
  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.high_availability.standby_replicas)
    error_message = "standby_replicas must be 'ENABLED' or 'DISABLED' (Pillar 4 — High Availability & Region Control)."
  }
}

# ── Pillar 6 — Backups & Deletion Protection ────────────────────────────────
# OpenSearch Serverless has NO native deletion-protection toggle, so retention
# is enforced via a data lifecycle (retention) policy. Backups are the
# service-managed automatic snapshots of the collection.
variable "backup" {
  description = "Retention via a data lifecycle policy (AOSS has no native deletion-protection toggle)."
  type = object({
    retention_days           = optional(number, 30)
    min_index_retention_days = optional(number, 30)
  })
  nullable = false
  default  = {}
  # NOTE: retention ≥ 30 is enforced via a lifecycle precondition on the
  # collection (see main.tf) — not a variable validation — so that
  # `tofu test` expect_failures can attach the error to the resource.
}

# ── Pillar 5 — Observability ────────────────────────────────────────────────
# OpenSearch Serverless data-plane audit is via CloudTrail (platform-level).
# The module exposes an SNS topic for a default collection-health alarm.
variable "observability" {
  description = "Centralized observability. AOSS data-plane audit is CloudTrail-based; alarms route to alarm_topic_arn."
  type = object({
    alarm_topic_arn    = optional(string, null)
    log_retention_days = optional(number, 90)
  })
  nullable = false
  default  = {}
  validation {
    condition     = var.observability.log_retention_days >= 30 || var.observability.log_retention_days == null
    error_message = "Log retention must be at least 30 days (Pillar 5 — Observability)."
  }
}

# ── Pillar 2 — Access Control & Least Privilege (IAM) ───────────────────────
# The module creates a data access policy granting ONLY these principals
# read/write on this collection. No wildcard principals, no aoss:* grants.
variable "iam" {
  description = "Principals allowed to read/write this collection. The data access policy is scoped to exactly these ARNs."
  type = object({
    principal_arns           = list(string) # e.g. arn:aws:iam::ACCOUNT:role/app-service
    permissions_boundary_arn = optional(string, null)
  })
  nullable = false
  validation {
    condition     = length(var.iam.principal_arns) >= 1
    error_message = "At least one IAM principal must be granted access to the collection (Pillar 2 — Access Control & Least Privilege)."
  }
}

# ── Pillar 7 — Data Residency & Sovereignty ──────────────────────────────
variable "data_classification" {
  description = "Data classification: internal, pii, phi, financial, cardholder"
  type        = string
  nullable    = false
  default     = "internal"
  validation {
    condition     = contains(["internal", "pii", "phi", "financial", "cardholder"], var.data_classification)
    error_message = "Must be one of: internal, pii, phi, financial, cardholder."
  }
}

variable "data_residency" {
  description = "Data residency constraints."
  type = object({
    sovereign_only                 = optional(bool, false)
    jurisdiction                   = optional(string, null)
    allow_cross_border_replication = optional(bool, false)
    cross_border_approval_ref      = optional(string, null)
  })
  nullable = false
  default  = {}
}

# ── Pillar 10 — FinOps & Cost Controls ──────────────────────────────────────────────────────
variable "cost_controls" {
  description = "FinOps tags and budget wiring."
  type = object({
    budget_amount = optional(number, null)
    budget_email  = optional(string, null)
    cost_center   = optional(string, null)
    project_code  = optional(string, null)
  })
  nullable = false
  default  = {}
}

variable "default_tags" {
  description = "Base tags merged onto every resource."
  type        = map(string)
  default     = {}
}