# Anestoa Infrastructure Platform — Requirements

> **Multi-account AWS landing zone + environment infrastructure for regulated industries.**
> Compliance-by-default OpenTofu modules using the terraservice pattern on **AWS**,
> meeting **HIPAA** and **SOC 2 Type II** mandates.
>
> Designed for insurtech, healthtech, and fintech companies deploying AI/LLM workloads
> — vector databases, GPU inference endpoints, large-scale training data pipelines.
>
> **Status:** Design phase. Architecture is documented; no OpenTofu code written yet.

---

## 1. Why This Exists

Target clients are AI infrastructure companies in regulated verticals that need:

1. A **multi-account landing zone** with compliance guardrails (SCPs, CloudTrail, GuardDuty)
2. **Environment-based account structure** — one account per environment per business unit,
   organized under `environments/`
3. A **hub-and-spoke VPC architecture** — Transit Gateway in a dedicated Network Hub account
   connecting all environment VPCs
4. **Terraservice-per-layer** within each account — IAM, network, data, compute, and AI
   are independently deployable with separate state files
5. **GenAI agentic runtime modules** — OpenSearch vector stores, Bedrock inference with
   guardrails, private SageMaker development, pgvector on RDS
6. **Compliance-by-default** — SCPs enforce encryption, region restriction, deletion protection,
   no public access at the organizational level. Opt out, not in.

This repo is the **demonstration and template**: walk a client through the architecture,
customize it for their structure, and deliver a production-ready platform.

---

## 2. Architecture Overview

### Organization Structure

```
Root
├── OU: Infra-Control-Plane (platform/infra team — shared control plane)
│   ├── Account: Management
│   ├── Account: Log Archive
│   ├── Account: Security
│   ├── OU: /Infra-Control-Plane/Network ─── Account: Network Hub
│   └── Account: Landing Zone (CI/CD)
│
├── OU: Production
│   ├── /Production/Platform      ─── production-platform
│   ├── /Production/Research      ─── production-research
│   └── /Production/DataPlatform  ─── production-data-platform
│
├── OU: Pre-Production
│   └── /Pre-Production/Platform  ─── preprod-platform
│
├── OU: Development
│   └── /Development/Platform     ─── dev-platform
│
└── OU: Sandbox
    └── Account: sandbox
```

### Repository Layout

```
infrastructure/
├── landing-zone/       bootstrap + baseline + reference docs
├── environments/       every AWS account in the org
│   ├── infrastructure/ shared-service accounts
│   ├── production/     production accounts per business unit
│   ├── preprod/        pre-production accounts
│   ├── development/    development accounts
│   └── sandbox/        sandbox account
├── modules/            reusable building blocks
├── .github/CODEOWNERS
├── CLAUDE.md
└── Makefile
```

### Key Design Decisions

| Decision | Rationale |
|---|---|
| **Environment as primary axis** | `environments/production/platform/` reads as "the platform team's production deployment." One directory = one AWS account. |
| **Landing zone + environments** | Matches AWS Organizations topology. Landing zone is the control plane; environments are what runs inside it. |
| **Hub-and-spoke VPC** | All VPCs connect through a central Transit Gateway in the Network Hub. Shared endpoints, no public IPs. |
| **Terraservice per layer** | Network, data, compute, and AI have different change frequencies and blast radii. Separate state = independent deploy. |
| **No ATS / Account Manager** | Small to mid-sized companies: `aws_organizations_account` + PR review is sufficient. |
| **No terraservice- prefix** | Directories are named what they do: `iam/`, `network/`, `data/`, `compute/`, `ai/`. |
| **GenAI modules** | `modules/opensearch-collection`, `bedrock-endpoint`, `bedrock-guardrail`, `sagemaker-domain`, `rds-pgvector`. |

---

## 3. SCP Enforcement

| SCP | Attach point | Effect |
|---|---|---|
| DenyRootUserActions | Root OU | All accounts |
| RestrictRegions | Root OU | All accounts |
| EnforceEncryptionAtRest | Root OU | All accounts |
| DenyCloudTrailDisable | Root OU | All accounts |
| ProtectLogArchiveBucket | Infrastructure OU | Log Archive account |
| DenyPublicAccess | Production, Pre-Production, Development OUs | All workload accounts |
| EnforceDeletionProtection | /Production/* OUs | Production accounts only |
| DenySnapshotSkip | /Production/* OUs | Production accounts only |

---

## 4. Modules (Planned)

| Priority | Module | Used by |
|---|---|---|
| P0 | `vpc` | All environment network/ terraservices, Network Hub |
| P0 | `s3-bucket` | All environment data/ terraservices |
| P0 | `kms-key` | All stateful terraservices |
| P0 | `iam-role` | All environment iam/ terraservices |
| P0 | `cross-account-role` | All accounts |
| P0 | `transit-gateway-attachment` | All environment network/ terraservices |
| P0 | `vpc-endpoint` | Network Hub |
| P1 | `opensearch-collection` | Environment data/ and ai/ terraservices |
| P1 | `bedrock-endpoint` | Environment ai/ terraservices |
| P1 | `bedrock-guardrail` | Environment ai/ terraservices |
| P1 | `sagemaker-domain` | Environment ai/ terraservices |
| P1 | `rds-pgvector` | Environment data/ terraservices |
| P2 | `ecs-cluster` | Environment compute/ terraservices |
| P2 | `ecs-service` | Environment compute/ terraservices |
| P2 | `elasticache` | Environment data/ terraservices |

---

## 5. AI Workload Patterns

| Pattern | Description | Compliance |
|---|---|---|
| **Private AI** | All workloads in private VPC via hub-and-spoke, no internet access | HIPAA 164.310(a)(2)(iv) |
| **Model Inference Audit** | Every Bedrock invocation logged with guardrails | HIPAA 164.312(b) |
| **Training Data Pipeline** | Encrypted S3 → SageMaker (VPC-only) → Model Registry | HIPAA 164.312(a)(2)(iv) |
| **Vector DB for RAG** | OpenSearch Serverless KMS-encrypted, VPC endpoint reachable | HIPAA 164.312(e)(1) |

---

## 6. Team Governance

Teams are defined in `.github/CODEOWNERS`, not as directories:

```github
landing-zone/                                    @infra-team
modules/                                         @infra-team
environments/infra-control-plane/                @infra-team
environments/*/*/network/                        @infra-team
environments/*/*/iam/                            @infra-team
environments/production/platform/*/data/         @platform-team @infra-team
environments/production/platform/*/compute/      @platform-team @infra-team
environments/production/platform/*/ai/           @ai-team @infra-team
environments/development/platform/*/data/        @platform-team @infra-team
environments/development/platform/*/compute/     @platform-team @infra-team
environments/development/platform/*/ai/          @ai-team @infra-team
```

---

## 7. Client Engagement

1. **Walk-through** — present the architecture: landing zone, environments, hub-and-spoke, modules
2. **Customize** — set their approved regions, business units, team names
3. **Bootstrap** — deploy org, OUs, SCPs, accounts
4. **Baseline** — deploy CloudTrail, GuardDuty, cross-account roles
5. **Network Hub** — deploy Transit Gateway + shared endpoints
6. **Onboard environments** — deploy terraservices per environment per business unit
7. **GenAI** — add OpenSearch, Bedrock, SageMaker modules for agentic runtimes