# ─────────────────────────────────────────────────────────────────────────────
# rds-pgvector module — Aurora PostgreSQL + pgvector + RDS Proxy (Pillars 1-10)
#
# Hybrid vector + relational store for agentic RAG. Follows the CLAUDE.md
# pillar conventions: kms_key_arn caller-provided, private-only, multi-AZ,
# deletion protection, retention ≥ 30, observability, data residency.
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
  description = "Cluster name. Prefixes resource names and tags."
  type        = string
  nullable    = false
}

# ── Pillar 1 — Encryption (caller-provided CMK) ─────────────────────
variable "kms_key_arn" {
  description = "CMK ARN for encryption at rest. Module does NOT create a key."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "Must be a valid KMS key ARN."
  }
}

# ── pgvector tuning ─────────────────────────────────────────────────────────
variable "pgvector" {
  description = "pgvector extension tuning for vector + relational RAG queries."
  type = object({
    enabled                  = optional(bool, true)
    vector_dimensions        = optional(number, 1536)   # matches ada-002 / text-embedding-3-large
    index_type               = optional(string, "hnsw") # hnsw | ivfflat
    index_maintenance_window = optional(string, "sun:03:00-sun:05:00")
    connection_pool_max      = optional(number, 100)
    enable_parallel_query    = optional(bool, true)
  })
  nullable = false
  default  = {}
  validation {
    condition     = contains(["hnsw", "ivfflat"], var.pgvector.index_type)
    error_message = "pgvector.index_type must be 'hnsw' or 'ivfflat'."
  }
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
  description = "Availability configuration. Aurora is multi-AZ by design; replica_count controls read replicas."
  type = object({
    replica_count = optional(number, 1)
  })
  nullable = false
  default  = { replica_count = 1 }
  validation {
    condition     = var.high_availability.replica_count >= 1
    error_message = "Aurora requires at least 1 cluster instance (Pillar 4 — High Availability & Region Control)."
  }
}

# ── Pillar 6 — Backup, DR & Deletion Protection ─────────────────────────────
variable "backup" {
  description = "Backup, retention, DR, and deletion protection. Offsite DR is a second-region Aurora Global Cluster (opt-in)."
  type = object({
    retention_days          = optional(number, 30)
    deletion_protection     = optional(bool, true)
    skip_final_snapshot     = optional(bool, false)
    preferred_backup_window = optional(string, "03:00-05:00")
    # Cross-region DR — secondary Aurora Global Cluster for offsite recovery.
    # Opt-in only. Gated to approved regions and PHI-sovereign (see preconditions).
    cross_region_replica = optional(bool, false)
    replica_region       = optional(string, null)
  })
  nullable = false
  default  = {}
  # NOTE: replica_region must be in allowed_regions when cross_region_replica
  # is true — enforced by the global-cluster lifecycle precondition (a variable
  # validation here cannot reference var.allowed_regions).
}

# ── Pillar 3 — Network Security & Isolation (private-only) ──────────────────
variable "network" {
  description = "Network placement. Private subnets only — no public IPs."
  type = object({
    vpc_id        = string
    subnet_ids    = list(string)
    private_only  = optional(bool, true)
    allowed_cidrs = optional(list(string), [])
  })
  nullable = false
}

# ── Pillar 5 — Observability ────────────────────────────────────────────────
variable "observability" {
  description = "Centralized observability destinations."
  type = object({
    log_group_name      = optional(string, null)
    log_retention_days  = optional(number, 90)
    alarm_topic_arn     = optional(string, null)
    detailed_monitoring = optional(bool, true)
  })
  nullable = false
  default  = {}
  validation {
    condition     = var.observability.log_retention_days >= 30 || var.observability.log_retention_days == null
    error_message = "Log retention must be at least 30 days (Pillar 5 — Observability)."
  }
}

# ── Pillar 2 — Access Control & Least Privilege (IAM) ────────────────────────────────────────
variable "iam" {
  description = "IAM configuration for the cluster."
  type = object({
    role_name_prefix         = optional(string, "app-")
    permissions_boundary_arn = optional(string, null)
  })
  nullable = false
  default  = {}
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

# ── Database credentials — RDS manages the master password in Secrets Manager ─
# The cluster uses manage_master_user_password = true, so RDS auto-generates the
# password, stores it in Secrets Manager, and rotates it automatically. Terraform
# never sees the password value. The secret ARN is available via the
# master_user_secret output.
variable "master_username" {
  description = "Master username for the Aurora cluster."
  type        = string
  nullable    = false
  default     = "appuser"
}

variable "secret_arn" {
  description = <<-EOF
    ARN of the Secrets Manager secret for RDS Proxy auth (auth_scheme = SECRETS).
    When null (default), the proxy uses the RDS-managed secret created by
    manage_master_user_password — the module outputs its ARN as
    master_user_secret_arn for the caller to read.
  EOF
  type        = string
  nullable    = true
  default     = null
}

# ── Pillar 10 — FinOps & Cost Controls ──────────────────────────────────────────────────────
variable "cost_controls" {
  description = "FinOps tags. Aurora Serverless for dev/test, provisioned for prod."
  type = object({
    budget_amount  = optional(number, null)
    instance_class = optional(string, null) # e.g. db.r7g.large for prod
    cost_center    = optional(string, null)
    project_code   = optional(string, null)
  })
  nullable = false
  default  = {}
}

variable "default_tags" {
  description = "Base tags merged onto every resource."
  type        = map(string)
  default     = {}
}