# Compute — ECS Cluster

> Part of `environments/development/research/`. Apply fourth (after `data/`).
> Reads remote state from `iam/` and `network/`.

## Purpose

Creates an ECS cluster for running containerized application workloads. Dev defaults to
Fargate-only (no EC2 capacity, no idle cost) with outside-hours shutdown.

| Resource | Module | Purpose |
|----------|--------|---------|
| ECS Cluster | `ecs-cluster` | Fargate-first container runtime |
| CloudWatch Logs | `ecs-cluster` | KMS-encrypted task log group |
| CloudWatch Alarms | `ecs-cluster` | CPU/memory reservation alarms |

### Dev-specific sizing

| Setting | Value | Why |
|---------|-------|-----|
| Capacity | Fargate only | No EC2 instances to manage, pay-per-task |
| Container Insights | Enabled | Debugging visibility in dev |
| Detailed monitoring | false | Saves costs |
| Shutdown outside hours | true (planned) | `cost_controls.shutdown_outside_hours` |

## Safety: blast radius

| Change | Blast radius | Why |
|--------|-------------|-----|
| Add capacity provider (EC2 ASG) | Low | New ASG attachment, no downstream changes |
| Change log retention | Low | Only affects this layer |
| Delete cluster | Low (in dev) | No downstream dependents — reschedule tasks |
| Change SG reference | Medium | Running tasks pick up new SG on restart |

## Remote state contract

**Reads** from `iam/` and `network/`:
- `iam.ecs_task_exec_role_arn` → task execution
- `iam.ecs_service_role_arn` → app code role (future ecs-service module)
- `network.vpc_id`, `network.app_subnet_ids` → task placement
- `network.default_security_group_id` → security

**Exports** (no downstream dependents currently)

## Customization points

1. **EC2 capacity** — Set `asg_arn` to attach GPU/compute-optimized instances
2. **Log retention** — Adjust `observability.log_retention_days` (minimum 30)
3. **Alarm topic** — Set `observability.alarm_topic_arn` for CPU/memory alerts
4. **Services** — ECS services are deployed separately (via CI/CD or the planned `ecs-service` module)

## Pillar compliance

| Pillar | How it's met |
|--------|-------------|
| 1 — Encryption | KMS-encrypted task log group |
| 3 — Network Isolation | Fargate tasks in private subnets, no public IPs |
| 4 — HA | Multi-AZ task spread |
| 5 — Observability | Container Insights, CPU/memory alarms |
| 10 — FinOps | Dev-sized Fargate (pay-per-task), outside-hours shutdown opt-in |
