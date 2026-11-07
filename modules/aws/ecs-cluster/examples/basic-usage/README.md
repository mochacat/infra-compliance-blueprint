# ECS Cluster — basic usage

Provisions a Fargate-first ECS cluster in existing private subnets with a
KMS-encrypted task log group.

```hcl
module "compute" {
  source = "git::https://github.com/anestoa/infrastructure//modules/aws/ecs-cluster?ref=v0.1.0"
  # ... see main.tf in this example
}
```

Requires a VPC + private subnets (from the `vpc` / `network` layer) and a KMS key
(from the `kms-key` module).