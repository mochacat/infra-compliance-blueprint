# ECS Cluster

A single, compliant-by-default **ECS cluster** for containerized AI/ML workloads
on AWS. This module manages **only** the cluster — ECS services/tasks are handled
by a separate `ecs-service` module. Fargate is the default capacity strategy
(serverless, no idle cost); EC2 capacity via an auto-scaling group is an explicit
opt-in for high-throughput or GPU workloads.

Part of the Anestoa infrastructure reference monorepo for regulated (HIPAA /
SOC 2) environments.

## What this creates

| Resource | Purpose |
|---|---|
| `aws_ecs_cluster` | The cluster with Container Insights + ECS Exec enabled |
| `aws_ecs_capacity_provider.ec2` (opt-in) | EC2 capacity when an ASG ARN is supplied |
| `aws_ecs_cluster_capacity_providers` | Registers Fargate/Fargate Spot (+ optional EC2) |
| `aws_cloudwatch_log_group.tasks` | Task logs, KMS-encrypted, retention ≥ 30d |
| `aws_cloudwatch_metric_alarm.cpu/memory` | Default reservation alarms when a topic is set |

## Compliance posture

| Pillar | Enforced |
|---|---|
| 1 Encryption | Task log group encrypted with caller-provided CMK (never module-created) |
| 3 Network isolation | Tasks placed in caller's private subnets; ≥1 security group required |
| 4 High availability | ≥2 private subnets required (multi-AZ); Fargate spreads by default |
| 5 Observability | Container Insights + default CPU/memory reservation alarms |
| 6 Backup/DR | Task log retention ≥ 30 days (no cluster-level deletion toggle) |
| 7 Residency | `data_classification` + `data_residency` gates (PHI ⇒ sovereign) |
| 10 FinOps | Cost tags required; Fargate-first by default |

Controls are enforced via **lifecycle preconditions** on the cluster, not variable
validations, so `tofu test` `expect_failures` and the OPA layer can gate plans.

## Usage

```hcl
module "compute" {
  source = "git::https://github.com/anestoa/infrastructure//modules/aws/ecs-cluster?ref=v0.1.0"

  environment = "prod"
  name        = "rag-workers"
  region      = "us-east-1"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abc"

  network = {
    vpc_id             = "vpc-0a1b2c3"
    subnet_ids         = ["subnet-0a1", "subnet-0a2"]
    security_group_ids = ["sg-0a1b2c3"]
  }

  data_classification = "phi"
  data_residency = {
    sovereign_only = true
    jurisdiction   = "US"
  }

  observability = {
    alarm_topic_arn    = "arn:aws:sns:us-east-1:123456789012:alarms"
    log_retention_days = 365
  }
}
```

## Inputs

See `variables.tf`. Required: `environment`, `name`, `region`, `kms_key_arn`,
`network`. All others default to a compliant posture.

## Outputs

`cluster_id`, `cluster_name`, `cluster_arn`, `task_log_group_name`,
`task_log_group_arn`, `capacity_provider_names`, and `compliance_controls`
(environment, encryption, multi-az, retention, data classification) for OPA /
drift evaluation.