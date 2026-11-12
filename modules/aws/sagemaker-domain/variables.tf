# ─────────────────────────────────────────────────────────────────────────────
# sagemaker-domain module — SageMaker Studio execution environment
#
# Pillar coverage:
#   1  Encryption:   all storage (EFS home, EBS, FSx) encrypted with caller CMK
#   2  Access:       dedicated least-privilege SageMaker execution role
#   3  Network:      ALWAYS VpcOnly — private subnets, no public access
#   4  HA:           domain spans ≥ 2 subnets (multi-AZ by construction)
#   5  Observability: CloudWatch alarm for Studio health (SNS)
#   6  Backup/DR:    EFS retention + deletion_protection on log groups
#   7  Residency:    data_classification + data_residency gates
#  10  FinOps:       default ml.t3.medium Studio instance, cost tags, budget
# ─────────────────────────────────────────────────────────────────────────────

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
  description = "Short name for the domain, e.g. 'ml-platform'. Used to prefix resource names."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.name))
    error_message = "Name may only contain letters, numbers, dashes, and underscores."
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
}

# ── Pillar 1 — Encryption (caller-provided CMK) ─────────────────────────────
variable "kms_key_arn" {
  description = "CMK ARN for encryption at rest (EFS, EBS, FSx). Module does NOT create a key."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "Must be a valid KMS key ARN."
  }
}

# ── Pillar 3 — Network Security & Isolation (VpcOnly, ALWAYS) ───────────────
# The SageMaker Domain is ALWAYS created in VpcOnly mode. There is no
# PublicInternetOnly path through this module.
variable "network" {
  description = "Network placement. The domain always runs VpcOnly; public access is impossible."
  type = object({
    vpc_id             = string
    subnet_ids         = list(string) # ≥ 2 subnets across distinct AZs
    security_group_ids = optional(list(string), [])
  })
  nullable = false
  # NOTE: subnet count is enforced via a lifecycle precondition on the domain
  # (see main.tf), not a variable validation, so `tofu test` expect_failures
  # can attach the error to the resource.
}

# ── Pillar 2 — Access Control & Least Privilege (IAM) ───────────────────────
# Module creates ONE dedicated SageMaker execution role scoped to the specific
# buckets/repos the workload uses. No wildcard Resource grants, no shared roles.
variable "iam" {
  description = "IAM for the SageMaker execution role."
  type = object({
    execution_role_name      = string # Role name for the dedicated execution role
    additional_policy_arns   = optional(list(string), [])
    permissions_boundary_arn = optional(string, null)
  })
  nullable = false
  validation {
    condition     = var.iam.execution_role_name != ""
    error_message = "execution_role_name must be provided (Pillar 2 — Access Control & Least Privilege)."
  }
}

# ── Pillar 4 — HA ────────────────────────────────────────────────────────────
variable "high_availability" {
  description = "Availability. The domain always spans all provided subnets (multi-AZ)."
  type = object({
    multi_az = optional(bool, true)
  })
  nullable = false
  default  = { multi_az = true }
}

# ── Pillar 5 — Observability ─────────────────────────────────────────────────
variable "observability" {
  description = "Centralized observability. SageMaker execution logs to CloudWatch; alarm routes to alarm_topic_arn."
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

# ── Pillar 6 — Backup, DR & Deletion Protection ──────────────────────────────
# SageMaker Domain itself has no native deletion-protection toggle (EFS is the
# durable home store). Retention is enforced on CloudWatch log groups.
variable "backup" {
  description = "Backup / retention. EFS home is auto-versioned by SageMaker; log retention is enforced here."
  type = object({
    retention_days      = optional(number, 30)
    deletion_protection = optional(bool, true)
  })
  nullable = false
  default  = {}
  # NOTE: retention >= 30 enforced via a precondition on the domain lifecycle
}

# ── Pillar 7 — Data Residency & Sovereignty ──────────────────────────────────
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
  description = "Data residency constraints"
  type = object({
    sovereign_only                 = optional(bool, false)
    jurisdiction                   = optional(string, null)
    allow_cross_border_replication = optional(bool, false)
    cross_border_approval_ref      = optional(string, null)
  })
  nullable = false
  default  = {}
}

# ── Pillar 10 — FinOps & Cost Controls ───────────────────────────────────────
variable "cost_controls" {
  description = "Cost management settings"
  type = object({
    budget_amount           = optional(number, null)
    budget_alert_thresholds = optional(list(number), [50, 80, 100])
    budget_email            = optional(string, null)
    studio_instance_type    = optional(string, "ml.t3.medium")
    shutdown_outside_hours  = optional(bool, false)
    cost_center             = optional(string, null)
    project_code            = optional(string, null)
  })
  nullable = true
  default  = null
}

# ── App-level configuration ──────────────────────────────────────────────────
variable "auth_mode" {
  description = "SageMaker Studio authentication: IAM or SSO."
  type        = string
  default     = "IAM"
  validation {
    condition     = contains(["IAM", "SSO"], var.auth_mode)
    error_message = "auth_mode must be IAM or SSO."
  }
}

variable "create_default_user" {
  description = "Create a default user profile so Studio has an initial user."
  type        = bool
  default     = true
}

variable "default_user_name" {
  description = "Name for the default user profile."
  type        = string
  default     = "default-user"
  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.default_user_name))
    error_message = "default_user_name may only contain letters, numbers, dashes, underscores."
  }
}

variable "default_landing_uri" {
  description = "Default landing URI for Studio users."
  type        = string
  default     = "https://studio.aws.sagemaker.aws"
}

variable "sagemaker_bucket_arns" {
  description = "S3 bucket ARNs the execution role may read/write. Least-privilege data access."
  type        = list(string)
  default     = []
}

variable "sagemaker_repository_arns" {
  description = "ECR repository ARNs the execution role may pull. Least-privilege image access."
  type        = list(string)
  default     = []
}

variable "default_tags" {
  description = "Base tags merged into all resources."
  type        = map(string)
  default     = {}
}