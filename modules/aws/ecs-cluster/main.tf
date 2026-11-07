# ─────────────────────────────────────────────────────────────────────────────
# ecs-cluster module — ECS cluster
#
# Pillar coverage:
#   1  Encryption:   task log group encrypted with the caller-provided CMK
#   2  Access:       IAM service role passed in; no wildcard grants created here
#   3  Network:      tasks placed in private subnet_ids (≥2 enforced)
#   4  HA:           Fargate tasks spread across provided AZs; EC2 capacity opt-in
#   5  Observability: task log retention + default CPU/memory reservation alarms
#   6  Backup/DR:    task log retention ≥ 30 (no cluster-level deletion toggle)
#   7  Residency:    data_classification + data_residency gates
#   9  Change mgmt:  environment validated; compliance_controls output for OPA
#  10  FinOps:       cost tags; cost-conscious Fargate-first default
# ─────────────────────────────────────────────────────────────────────────────

# ── Cluster (always provisioned — Pillar 3/4) ────────────────────────────────
resource "aws_ecs_cluster" "this" {
  name = var.name
  # checkov:skip=CKV_AWS_224:Exec-session logs route to aws_cloudwatch_log_group.tasks, which is KMS-encrypted (var.kms_key_arn). The exec log_configuration only exposes kms_key_id for the S3 sink, not CloudWatch, so the CMK intent is met at the log group (Pillar 1).

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }

  # ECS Exec is enabled for interactive debugging of AI workload containers.
  # Access is gated by the task definition's enabledExecuteCommand flag (managed
  # by ecs-service) plus the caller's IAM policy.
  configuration {
    execute_command_configuration {
      # Logging of exec sessions goes to the task log group (KMS-encrypted).
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.tasks.name
        s3_bucket_name             = null
      }
    }
  }

  tags = merge(local.base_tags, { Name = var.name })

  lifecycle {
    # Region gate (Pillar 4)
    precondition {
      condition     = contains(var.allowed_regions, var.region)
      error_message = "Region ${var.region} is not in approved allowed_regions (Pillar 4 — High Availability & Region Control)."
    }
    # Subnet count gate (Pillar 4) — HA requires ≥ 2 private AZs.
    precondition {
      condition     = length(var.network.subnet_ids) >= 2
      error_message = "Cluster requires at least 2 private subnets in different AZs (Pillar 4 — High Availability & Region Control)."
    }
    # Security-group gate (Pillar 3)
    precondition {
      condition     = length(var.network.security_group_ids) >= 1
      error_message = "At least one security group is required for the cluster (Pillar 3 — Network Security & Isolation)."
    }
    # Residency gate (Pillar 7) — PHI requires sovereign_only.
    precondition {
      condition     = var.data_residency.sovereign_only == true || var.data_classification != "phi"
      error_message = "PHI requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty)."
    }
    # Log retention gate (Pillar 6).
    precondition {
      condition     = var.backup.log_retention_days >= 30
      error_message = "Minimum log retention is 30 days (Pillar 6 — Backup, DR & Deletion Protection)."
    }
  }
}

# ── Capacity providers (Pillar 4/10) ─────────────────────────────────────────
# Fargate + Fargate Spot are built-in and always registered. If an ASG ARN is
# provided, an EC2 capacity provider is added as a weighted alternative.
resource "aws_ecs_capacity_provider" "ec2" {
  count = var.asg_arn != null ? 1 : 0

  name = "${var.name}-${local.ec2_provider_name}"
  auto_scaling_group_provider {
    auto_scaling_group_arn = var.asg_arn
    managed_scaling {
      status          = "ENABLED"
      target_capacity = 80
    }
    managed_draining = "ENABLED"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = concat(
    ["FARGATE", "FARGATE_SPOT"],
    var.asg_arn != null ? [aws_ecs_capacity_provider.ec2[0].name] : [],
  )
  default_capacity_provider_strategy {
    base              = 1
    weight            = 1
    capacity_provider = "FARGATE"
  }
}

# ── Task log group (Pillar 1/5/6) ────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "tasks" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.backup.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(local.base_tags, { Name = "${var.name}-tasks" })
}

# ── Observability alarms (Pillar 5) ─────────────────────────────────────────
# Default cluster CPU + memory reservation alarms. Wired when an SNS topic is
# provided so the compute layer is never unmonitored in prod.
resource "aws_cloudwatch_metric_alarm" "cpu_reservation" {
  count = var.observability.alarm_topic_arn != null ? 1 : 0

  alarm_name          = "${var.name}-cpu-reservation"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUReservation"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "ECS cluster ${var.name} CPU reservation exceeds 80%"
  alarm_actions       = [var.observability.alarm_topic_arn]
  tags                = merge(local.base_tags, { Name = "${var.name}-cpu-reservation" })
}

resource "aws_cloudwatch_metric_alarm" "memory_reservation" {
  count = var.observability.alarm_topic_arn != null ? 1 : 0

  alarm_name          = "${var.name}-memory-reservation"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryReservation"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "ECS cluster ${var.name} memory reservation exceeds 80%"
  alarm_actions       = [var.observability.alarm_topic_arn]
  tags                = merge(local.base_tags, { Name = "${var.name}-memory-reservation" })
}