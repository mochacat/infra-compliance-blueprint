# Landing Zone

> Multi-account AWS foundation for regulated AI/LLM infrastructure workloads.
> This is a **reference architecture** — a client-facing template, not a deployed project.

## Overview

The landing zone establishes the AWS Organizations structure, account baseline, and
centralized security/logging that every environment depends on. It is split into
two terraservices based on change frequency:

| Terraservice | Changes | State location | What it manages |
|---|---|---|---|
| `bootstrap/` | Quarterly/yearly | Management account | Org, OUs, SCPs, account creation |
| `baseline/` | Monthly | Management account (assumes roles) | CloudTrail, S3, GuardDuty, Security Hub, cross-account roles |

## OU Structure

```
Root
├── OU: Infra-Control-Plane
│   ├── OU: /Infra-Control-Plane/Network ─── Account: network-hub
│   ├── Account: Management
│   ├── Account: Log Archive
│   ├── Account: Security
│   └── Account: Landing Zone (CI/CD)
│
├── OU: Production
│   ├── OU: /Production/Platform      ─── Account: production-platform
│   └── OU: /Production/Research      ─── Account: production-research
│
├── OU: Pre-Production
│   └── OU: /Pre-Production/Platform  ─── Account: preprod-platform
│
├── OU: Development
│   └── OU: /Development/Platform     ─── Account: dev-platform
│
└── OU: Sandbox ─── Account: sandbox
```

## Reference Documents

| Document | Description |
|---|---|
| [ARCHITECTURE.md](reference/ARCHITECTURE.md) | Full design — accounts, OUs, SCPs, hub-and-spoke VPC, terraservice split, compliance |
| [SCP-DESIGN.md](reference/SCP-DESIGN.md) | Service Control Policy catalog — 8 JSON policies with OU attachment strategy |
| [STATE-STRATEGY.md](reference/STATE-STRATEGY.md) | State management across accounts, bootstrap flow, access control |
| [GENAI-RUNTIME.md](reference/GENAI-RUNTIME.md) | GenAI agentic runtime module designs (OpenSearch, Bedrock, SageMaker, pgvector) |

## Quick Links

- [Bootstrap Terraservice](bootstrap/README.md) — org, OUs, SCPs, accounts
- [Baseline Terraservice](baseline/README.md) — centralized security & logging