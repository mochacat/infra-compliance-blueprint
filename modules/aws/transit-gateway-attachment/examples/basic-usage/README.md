# TGW Attachment — basic usage

Attaches a workload VPC to the Network Hub's Transit Gateway for inter-VPC
routing and centralized network inspection. This is the standard pattern every
workload environment follows.

## Usage

```bash
cd examples/basic-usage
tofu init
tofu plan
```