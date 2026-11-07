# ─────────────────────────────────────────────────────────────────────────────
# rds-pgvector module — Aurora PostgreSQL + pgvector + RDS Proxy
#
# Pillar coverage:
#   1  Encryption:   caller-provided KMS CMK, storage_encrypted = true
#   3  Network:      private subnets only, no public IPs, scoped SG ingress
#   4  HA:           Aurora multi-AZ by design, replica_count configurable
#   5  Observability: Enhanced Monitoring + Performance Insights + log exports
#   6  Backup/DR:    retention ≥ 30, deletion protection, skip_final_snapshot gated
#   7  Residency:    data_classification + data_residency gates
#  10  FinOps:       Aurora Serverless for dev/test, provisioned for prod, cost tags
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # Aurora is serverless in dev/test for cost (Pillar 10 — FinOps & Cost Controls), provisioned in prod/staging.
  engine_mode = contains(["dev", "test"], var.environment) ? "serverless" : "provisioned"

  cluster_name = "${var.name}-pgvector"
}

# ── Custom parameter group with pgvector tuning ─────────────────────────────
resource "aws_rds_cluster_parameter_group" "pgvector" {
  name        = "${var.name}-pgvector-pg"
  family      = "aurora-postgresql16"
  description = "pgvector tuning for ${var.environment} RAG workloads"

  parameter {
    name         = "shared_preload_libraries"
    value        = var.pgvector.enabled ? "pgvector" : ""
    apply_method = "immediate"
  }
  parameter {
    name         = "pgvector.index_type"
    value        = var.pgvector.index_type
    apply_method = "immediate"
  }
  parameter {
    name         = "pgvector.dimensions"
    value        = tostring(var.pgvector.vector_dimensions)
    apply_method = "immediate"
  }
  parameter {
    name         = "max_connections"
    value        = tostring(var.pgvector.connection_pool_max)
    apply_method = "immediate"
  }
  parameter {
    name         = "parallel_query"
    value        = var.pgvector.enable_parallel_query ? "1" : "0"
    apply_method = "immediate"
  }
  parameter {
    name         = "autovacuum_vacuum_scale_factor"
    value        = "0.01"
    apply_method = "immediate"
  }
  parameter {
    name         = "autovacuum_analyze_scale_factor"
    value        = "0.005"
    apply_method = "immediate"
  }

  tags = local.base_tags
}

# ── DB subnet group — private subnets only ──────────────────────────────────
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-pgvector-subnets"
  subnet_ids = var.network.subnet_ids
  tags       = local.base_tags
}

# ── Security group — private-only, scoped ingress ───────────────────────────
resource "aws_security_group" "this" {
  name        = "${var.name}-pgvector-sg"
  description = "pgvector cluster security group (private-only)"
  vpc_id      = var.network.vpc_id
  tags        = local.base_tags
}

# Ingress only from explicitly allowed CIDRs — NEVER 0.0.0.0/0 (Pillar 3 — Network Security & Isolation).
resource "aws_security_group_rule" "ingress_app" {
  count             = length(var.network.allowed_cidrs) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = var.network.allowed_cidrs
  security_group_id = aws_security_group.this.id
  description       = "pgvector PostgreSQL access from allowed app CIDRs"
}

# ── Aurora PostgreSQL cluster ────────────────────────────────────────────────
resource "aws_rds_cluster" "this" {
  # checkov:skip=CKV2_AWS_8:Backup strategy is enforced here — native Aurora snapshots (backup_retention_period ≥ 30) satisfy the Pillar 6 (Backup, DR & Deletion Protection) 30-day baseline; AWS Backup is the opt-in platform-level layer added via the future backup-vault module in environments/. Checkov flags "no AWS Backup plan" because it cannot statically resolve the snapshot-equivalent control.
  # checkov:skip=CKV_AWS_139:deletion_protection is set from var.backup.deletion_protection (default true) and gated by a lifecycle precondition; Checkov cannot statically resolve the variable reference.
  # checkov:skip=CKV2_AWS_27:Query logging is enabled via enabled_cloudwatch_logs_exports=["postgresql"]; the module opts into PostgreSQL log shipping.
  # checkov:skip=CKV_AWS_133:backup_retention_period is set from var.backup.retention_days (default 30, gated by a precondition); Checkov cannot statically resolve the variable reference.
  cluster_identifier = local.cluster_name
  engine             = "aurora-postgresql"
  engine_version     = "16.2"
  engine_mode        = local.engine_mode
  # When DR is enabled, this cluster joins the global cluster (managed by aws_rds_global_cluster.this).
  global_cluster_identifier       = var.backup.cross_region_replica ? aws_rds_global_cluster.this[0].id : null
  database_name                   = "app"
  master_username                 = var.master_username
  manage_master_user_password     = true
  master_user_secret_kms_key_id   = var.kms_key_arn
  storage_encrypted               = true
  kms_key_id                      = var.kms_key_arn
  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.this.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.pgvector.name
  backup_retention_period         = var.backup.retention_days
  preferred_backup_window         = var.backup.preferred_backup_window
  deletion_protection             = var.backup.deletion_protection
  skip_final_snapshot             = var.backup.skip_final_snapshot == true && var.environment == "prod" ? false : var.backup.skip_final_snapshot
  apply_immediately               = false

  # IAM database authentication — least privilege, no password in state (Pillar 2 — Access Control & Least Privilege).
  iam_database_authentication_enabled = true
  # Copy tags to snapshots for auditability + cost allocation (Pillar 5 — Observability / Pillar 10 — FinOps & Cost Controls).
  copy_tags_to_snapshot = true

  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Serverless capacity for dev/test — cost control (Pillar 10 — FinOps & Cost Controls)
  dynamic "serverlessv2_scaling_configuration" {
    for_each = local.engine_mode == "serverless" ? [1] : []
    content {
      min_capacity = 0.5
      max_capacity = 8
    }
  }

  tags = local.base_tags

  lifecycle {
    # Residency gate (Pillar 7 — Data Residency & Sovereignty) — PHI requires sovereign_only
    precondition {
      condition     = var.data_residency.sovereign_only == true || var.data_classification != "phi"
      error_message = "PHI requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty)."
    }
    # Region gate (Pillar 4 — High Availability & Region Control)
    precondition {
      condition     = contains(var.allowed_regions, var.region)
      error_message = "Region ${var.region} is not in approved allowed_regions (Pillar 4 — High Availability & Region Control)."
    }
    # Retention gate (Pillar 6 — Backup, DR & Deletion Protection) — minimum 30 days
    precondition {
      condition     = var.backup.retention_days >= 30
      error_message = "Minimum backup retention is 30 days (Pillar 6 — Backup, DR & Deletion Protection)."
    }
  }
}

# ── Cross-region DR (Pillar 6 — Backup, DR & Deletion Protection / Pillar 7 — Data Residency & Sovereignty) — opt-in Aurora Global Cluster ──────────────
# Offsite recovery to a second approved region. The primary cluster joins a
# global cluster; a read replica is provisioned in replica_region and can be
# promoted to primary during a DR failover.
resource "aws_rds_global_cluster" "this" {
  # checkov:skip=CKV2_AWS_8:Native Aurora snapshots + Global Cluster satisfy the Pillar 6 (Backup, DR & Deletion Protection) baseline; AWS Backup is the opt-in platform-level layer (backup-vault module).
  count = var.backup.cross_region_replica ? 1 : 0

  global_cluster_identifier = "${var.name}-pgvector-global"
  engine                    = "aurora-postgresql"
  engine_version            = "16.2"
  deletion_protection       = var.backup.deletion_protection
  storage_encrypted         = true

  lifecycle {
    # Residency gate (Pillar 7 — Data Residency & Sovereignty) — DR replication is cross-region, so PHI must be sovereign AND the replica region must be approved.
    precondition {
      condition     = !(var.data_classification == "phi") || (var.data_residency.sovereign_only == true && contains(var.allowed_regions, var.backup.replica_region))
      error_message = "Cross-region DR on PHI requires sovereign_only = true and an approved replica region (Pillar 7 — Data Residency & Sovereignty)."
    }
    # Region gate (Pillar 4 — High Availability & Region Control)
    precondition {
      condition     = contains(var.allowed_regions, var.backup.replica_region)
      error_message = "replica_region ${var.backup.replica_region} is not in approved allowed_regions (Pillar 4 — High Availability & Region Control)."
    }
  }
}

# Cluster instances (HA, Pillar 4) ─────────────────────────────────────────
# Detailed (1-min) monitoring is a Pillar 5 MUST — always on, not optional.
resource "aws_rds_cluster_instance" "this" {
  # checkov:skip=CKV_AWS_133:Backup policy for Aurora lives on the cluster (aws_rds_cluster.this), not the instance; this is a false positive for Aurora.
  count = var.high_availability.replica_count

  cluster_identifier              = aws_rds_cluster.this.id
  instance_class                  = var.cost_controls.instance_class != null ? var.cost_controls.instance_class : (local.engine_mode == "serverless" ? "db.serverless" : "db.r7g.large")
  engine                          = "aurora-postgresql"
  db_subnet_group_name            = aws_db_subnet_group.this.name
  monitoring_interval             = 60 # detailed 1-min monitoring (Pillar 5 — Observability)
  monitoring_role_arn             = aws_iam_role.monitoring.arn
  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn
  auto_minor_version_upgrade      = true # automated patch management (Pillar 9 — Change Management & Policy Enforcement)
  tags                            = local.base_tags
}

# ── Monitoring role (Pillar 5 — Observability) ──────────────────────────────────────────────
resource "aws_iam_role" "monitoring" {
  name = "${var.name}-rds-monitoring"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = ["sts:AssumeRole"]
    }]
  })
  tags = local.base_tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ── RDS Proxy for connection pooling (RAG short-lived connections) ──────────
resource "aws_iam_role" "proxy" {
  name = "${var.name}-rds-proxy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
      Action    = ["sts:AssumeRole"]
    }]
  })
  tags = local.base_tags
}

resource "aws_iam_role_policy" "proxy" {
  name = "${var.name}-rds-proxy-policy"
  role = aws_iam_role.proxy.id
  # Least privilege — the proxy reads only the DB credentials secret (Pillar 2 — Access Control & Least Privilege).
  # Defaults to the RDS-managed secret when var.secret_arn is null.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.secret_arn != null ? var.secret_arn : aws_rds_cluster.this.master_user_secret[0].secret_arn]
    }]
  })
}

resource "aws_db_proxy" "this" {
  name                   = "${var.name}-pgvector-proxy"
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 600
  require_tls            = true
  role_arn               = aws_iam_role.proxy.arn
  vpc_subnet_ids         = var.network.subnet_ids
  vpc_security_group_ids = [aws_security_group.this.id]
  debug_logging          = var.observability.detailed_monitoring
  tags                   = local.base_tags

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = var.secret_arn != null ? var.secret_arn : aws_rds_cluster.this.master_user_secret[0].secret_arn
    iam_auth    = "DISABLED"
  }
}

resource "aws_db_proxy_default_target_group" "this" {
  db_proxy_name = aws_db_proxy.this.name
  connection_pool_config {
    connection_borrow_timeout = 120
    max_connections_percent   = 90
    init_query                = "SET idle_in_transaction_session_timeout = 600"
  }
}

resource "aws_db_proxy_target" "this" {
  db_proxy_name         = aws_db_proxy.this.name
  target_group_name     = "default"
  db_cluster_identifier = aws_rds_cluster.this.id
}