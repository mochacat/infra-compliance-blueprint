# basic-usage

Minimal usage of the `aws/vpc` module: a compliant multi-AZ private VPC with
flow logs optionally shipped to an immutable audit bucket.

## Run

```bash
tofu init
tofu plan
tofu apply
```

## Wiring

- Set `audit_bucket_arn` to an immutable Log Archive bucket to enable VPC Flow
  Logs (Pillars 5 & 8). Leave it `null` to skip flow logs for a pure-offline
  plan.
- Consume `module.workload_vpc.subnet_ids` in downstream compute / data / GenAI
  modules for private placement.
- The default SG is locked to deny-all; add your own security groups for
  explicit traffic rules.