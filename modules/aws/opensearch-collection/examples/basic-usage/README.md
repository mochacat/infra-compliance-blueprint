# Basic usage

A compliant, private OpenSearch Serverless vector collection wired to a caller-provided
VPC, KMS key, and app IAM role.

## What it creates

- An `aws_opensearchserverless_collection` of type `VECTORSEARCH` (1536-dim).
- A private `aws_opensearchserverless_vpc_endpoint` (module-managed).
- An encryption security policy bound to the caller's CMK.
- A network security policy with `AllowFromPublic: false` sourced only to the endpoint.
- A least-privilege data access policy scoped to the app role.
- A data lifecycle policy for index retention (default 30 days).

## Compliance note

There is **no option** to make this collection public or use an AWS-owned key. The VPC endpoint,
private network policy, and CMK encryption are always provisioned — that's the point of the module.