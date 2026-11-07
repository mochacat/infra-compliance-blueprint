# network-hub / endpoints

> **Infra-team OWNED** shared VPC endpoints for the network hub (Pillar 3 — Network
> Security & Isolation).

## Status: placeholder

This terraservice is **not yet implemented**. It will provision the **shared VPC endpoints**
(Gateway and Interface endpoint types) that workload VPCs rely on for private, in-VPC access
to AWS services without passing traffic over the public internet.

Reusable building block: `modules/aws/vpc-endpoint`.

## Planned scope (when implemented)

- Gateway endpoints: S3, DynamoDB
- Interface endpoints: as declared by the hub's consumers (SSM, ECR, ECS, CloudWatch, SQS, …)
- Private DNS enabled for each interface endpoint
- Security groups scoped to the hub

## Cross-account note (design decision pending)

SSM parameters are **account-local** and cannot be read cross-account, so distinct shared
endpoints are exposed to workload accounts differently from the hub TG (which uses a RAM share).
Planned options — to be decided when this layer is built (apply order item 2):

- **AWS PrivateLink / centralized VPC Endpoints** (ideal for most interface endpoints): the hub
  hosts the endpoints; workload accounts connect via `vpc_endpoint` in their own VPCs configured
  to reach the hub's endpoints, with the **endpoint DNS / IDs published via RAM or** a documented
  SSM pointer the consuming `network/` layer reads from its **own** account.
- **Gateway endpoints (S3, DynamoDB)**: typically created per-VPC in each workload account rather
  than shared, so there's usually no cross-account read at all.

Whatever the choice, the consumer must be able to resolve the endpoint **from its own account**
(+ region) — never via a cross-account SSM read.

Create this terraservice **after** `transit-gateway/` and before any workload `network/` layers
(apply order item 2).