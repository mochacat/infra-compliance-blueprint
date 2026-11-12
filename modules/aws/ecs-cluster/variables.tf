# ─────────────────────────────────────────────────────────────────────────────
# ecs-cluster module — Container runtime (Pillars 1-10)
#
# A single ECS cluster with Fargate-first capacity providers, task-log
# retention, and default CPU/memory reservation alarms. Used by
# environments/*/*/compute/ terraservices for containerized AI workloads.
#
# NOTE: this module manages ONLY the cluster (one resource type per module).
# ECS services/tasks are provisioned by the planned ecs-service module.
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

# ── Pillar 1 — Encryption (caller-provided CMK) ─────────────────────────────
# Used to encrypt task log group and any EC2-backed storage. Fargate platform
# storage is encrypted by AWS-managed side; when EC2 capacity is attached via
# an ASG, its EBS volumes are caller-managed and should use this CMK.
variable "kms_key_arn" {
  description = "CMK ARN for encryption at rest. Module does NOT create a key."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "Must be a valid KMS key ARN."
  }
}

# ── Pillar 3 — Network Security & Isolation ─────────────────────────────────
# ECS placement subnets. Fargate tasks land in these private subnets; when EC2
# capacity via an ASG is attached, the capacity provider's instances also run
# in/behind these private subnets (managed by the caller's ASG).
variable "network" {
  description = "Network placement. Private subnets for tasks; ≥2 required for HA."
  type = object({
    vpc_id             = string
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  nullable = false
  # NOTE: subnet (≥2) and security-group (≥1) counts are enforced via lifecycle
  # preconditions on the cluster (see main.tf) — not variable validations — so
  # `tofu test` expect_failures can attach them to the resource.
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
  description = "Multi-AZ spread and region control (Pillar 4)."
  type = object({
    multi_az = optional(bool, true)
  })
  nullable = false
  default  = { multi_az = true }
}

# ── Pillar 6 — Backups & Deletion Protection ────────────────────────────────
# ECS clusters have no native deletion-protection toggle; the durable data
# lives outside the cluster (RDS, S3, OpenSearch). The cluster's own retained
# artifact is the task log group, whose retention is enforced here.
variable "backup" {
  description = "Log retention. ECS has no deletion-protection toggle; retention applies to the task log group."
  type = object({
    log_retention_days = optional(number, 90)
  })
  nullable = false
  default  = {}
  # NOTE: retention ≥ 30 is enforced via a lifecycle precondition on the
  # cluster (see main.tf) — not a variable validation — so that
  # `tofu test` expect_failures can attach the error to the resource.
}

# ── Pillar 5 — Observability ────────────────────────────────────────────────
variable "observability" {
  description = "Centralized observability: task-log retention and a default cluster-health alarm."
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
variable "iam" {
  description = "IAM configuration for the cluster and optional EC2 capacity."
  type = object({
    service_role_arn     = optional(string, null) # ECS service-linked role; default created by AWS
    execution_role_arn   = optional(string, null) # task execution role (managed by ecs-service)
    permissions_boundary = optional(string, null)
    asg_managed_role     = optional(string, null) # AMI/ASG role for EC2 capacity instances
  })
  nullable = false
  default  = {}
}

# ── Pillar 7 — Data Residency & Sovereignty ─────────────────────────────────
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

# ── Pillar 10 — FinOps & Cost Controls ─────────────────────────────────────
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

# ── Capacity (Pillar 10 — cost-conscious sizing) ────────────────────────────
# Fargate is the default (serverless, no idle capacity). EC2 via an ASG is an
# explicit opt-in for high-throughput / GPU workloads where per-task pricing
# is not cost-effective.
variable "asg_arn" {
  description = "Optional ARN of an auto-scaling group providing EC2 capacity. When set, registers an EC2 capacity provider alongside Fargate."
  type        = string
  nullable    = true
  default     = null
}

variable "capacity_provider_name" {
  description = "Name for the optional EC2 capacity provider. Defaults to derive from the ASG."
  type        = string
  nullable    = true
  default     = null
}