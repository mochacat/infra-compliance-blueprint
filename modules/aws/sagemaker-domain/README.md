# SageMaker Domain

OpenTofu module that provisions an **always-private** SageMaker Studio domain for
**fine-tuning and training** workloads (the GenAI / ML side of the platform,
complementing the `opensearch-collection` vector store for training-data
pipelines). Complaint-by-default for regulated (HIPAA / SOC 2) environments.

## What it creates

- **`aws_sagemaker_domain`** — Studio domain, ALWAYS `VpcOnly` (no public drug).
  All storage (EFS home directories, EBS, FSx) is encrypted with the caller-provided
  KMS CMK.
- **`aws_sagemaker_user_profile`** — one default user profile (optional).
- **`aws_iam_role`** + inline policy — a dedicated SageMaker execution role scoped
  to the exact S3 buckets and ECR repositories the workload needs. No wildcard
  `Resource`.
- **`aws_sagemaker_studio_lifecycle_config`** — optional JupyterServer setup script.
- **`aws_cloudwatch_metric_alarm`** — Studio health alarm when `alarm_topic_arn` is set.

## Design (compliant by default — nothing to break)

- **No public-access toggle.** The domain is *always* `VpcOnly`; there is no
  `PublicInternetOnly` path through this module.
- **KMS encryption is mandatory.** `kms_key_arn` is required and validated; the
  module refuses to create an unencrypted or AWS-owned-key domain.
- **Least privilege.** The execution role grants only the named S3/ECR resources.
  `principal` is scoped, `Resource` never `"*"`.
- **No env-name checks.** Gates are lifecycle preconditions (PHI-sovereignty,
  region, multi-AZ, retention), not string checks on `environment`.

## Pillar coverage

| Pillar | Control | Where |
|---|---|---|
| 1 — Encryption | All storage CMK-encrypted | `kms_key_id = var.kms_key_arn` |
| 2 — Access | Dedicated scoped execution role | `aws_iam_role.execution` + inline policy |
| 3 — Network isolation | Always VpcOnly | `app_network_access_type = "VpcOnly"` |
| 4 — HA / region | Multi-AZ, region gate | precondition on domain |
| 5 — Observability | Studio health alarm | `aws_cloudwatch_metric_alarm.studio_health` |
| 6 — Backup/DR | Retention ≥ 30 days | precondition |
| 7 — Residency | PHI ⇒ sovereign_only | precondition |
| 10 — FinOps | Default `ml.t3.medium`, cost tags | `cost_controls` |

## Usage

```hcl
module "sagemaker_domain" {
  source  = "git::https://github.com/yourorg/infrastructure.git//modules/aws/sagemaker-domain?ref=v1.0.0"

  environment = "prod"
  name        = "ml-training"
  region      = "us-east-1"
  kms_key_arn = module.kms.data_key_arn      # from the kms-key module

  network = {
    vpc_id             = module.network.vpc_id
    subnet_ids         = module.network.private_subnet_ids
    security_group_ids = module.network.studio_security_group_ids
  }

  iam = {
    execution_role_name   = "ml-training-exec"
    permissions_boundary_arn = "arn:aws:iam::123456789012:policy/boundary"
  }

  sagemaker_bucket_arns   = ["arn:aws:s3:::ml-training-data"]
  cost_controls = {
    cost_center = "platform"
  }
  data_classification = "internal"
}
```

**Note on VPC endpoints:** SageMaker API / Studio VPC endpoints are managed by the
`vpc-endpoint` module in the `network` layer — not here. The domain references the
caller's VPC/subnets; the network team wires the endpoints. This keeps the
workload layer (domain + execution role) separate from the infra-team-owned
network layer.

## Variables

| Variable | Type | Default | Notes |
|---|---|---|---|
| `environment` | string | — | dev/test/staging/prod/commercial |
| `name` | string | — | domain name, resource prefix |
| `region` | string | — | must be in `allowed_regions` |
| `kms_key_arn` | string | — | required CMK ARN |
| `network` | object | — | vpc/subnets (≥2)/security groups |
| `iam` | object | — | execution role name, boundaries |
| `auth_mode` | string | `"IAM"` | IAM or SSO |
| `create_default_user` | bool | `true` | also gates lifecycle config |
| `sagemaker_bucket_arns` | list | `[]` | scoped S3 grants |
| `sagemaker_repository_arns` | list | `[]` | scoped ECR grants |
| `cost_controls` | object | `null` | studio instance type, budget |

## Outputs

`domain_id`, `domain_arn`, `domain_url`, `home_efs_file_system_id`,
`default_user_profile_name`, `execution_role_arn`, `compliance_controls`.

## Compliance checks

- **`tofu test`** — `defaults`, `prod`, and `compliance` (refuses PHI-without-sovereign,
  unapproved region, single-subnet).
- **Checkov** — see `checkov` run; skips documented inline.
- **OPA** (`policies/sagemaker-domain.rego`) — fails if not VpcOnly, missing CMK,
  wildcard role policy, or no `CostCenter` tag.