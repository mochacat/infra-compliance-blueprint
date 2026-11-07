# VPC Endpoint — basic usage

Creates private Gateway + Interface VPC endpoints for a workload VPC. Keeps all
traffic within the AWS network (no public internet) — the transmission security
control required by HIPAA 164.312(e)(1) and SOC 2 CC6.7.

## Usage

```bash
cd examples/basic-usage
tofu init
tofu plan
```