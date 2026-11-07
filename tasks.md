# Infrastructure Tasks

_Build status tracker for the Anestoa platform. Live checklist — updated on every PR; check items off as they merge. Canonical index of all outstanding work across the design docs._

## Legend & conventions

- `[ ]` not started · `[x]` in progress or done · `(blocked)` gated by an upstream prerequisite.
- Line items are grounded in the current docs: `REQUIREMENTS.md`, `landing-zone/reference/*.md`, `README.md`, and `CLAUDE.md`. A promise in a doc that has no code on disk is a `[ ]` item.
- State key matches the terraservice path (`environments/production/platform/network.tfstate`).
- Each module's gate per `CLAUDE.md`: `main/variables/outputs/locals/versions` **and** `tests/*.tftest.hcl` **and** `README.md` **and** `examples/` **and** `policies/*.rego` (optional) — required before release.

---

## 1. Landing zone (control plane)

Docs: `landing-zone/README.md`, `landing-zone/reference/ARCHITECTURE.md`, `SCP-DESIGN.md`, `STATE-STRATEGY.md`.

### 1.1 Reference docs
- [x] ARCHITECTURE.md — accounts, OUs, SCPs, hub-and-spoke VPC, terraservice split, HIPAA/SOC 2 mapping
- [x] SCP-DESIGN.md — 8-policy SCP catalog with JSON + OU attachment strategy
- [x] STATE-STRATEGY.md — state layout, backend, bootstrap flow, cross-account access
- [x] GENAI-RUNTIME.md — GenAI agentic runtime module designs

### 1.2 Bootstrap terraservice (`landing-zone/bootstrap/`)
- [x] Organization (`aws_organizations_organization`, ALL features) + service principals — `main.tf`
- [x] OU structure (Infrastructure/Network, Production/{Platform,Research,DataPlatform}, Pre-Production/{Platform,Research}, Development/{Platform,Research}, Sandbox) — `main.tf`
- [x] 9 SCPs wired to OUs — `scps.tf` + `policies/*.json` (deny-root-actions, restrict-regions, enforce-encryption, deny-cloudtrail-disable, deny-public-access, enforce-deletion-protection, deny-snapshot-skip, protect-log-archive, enforce-tags)
- [x] IAM Identity Center admin permission set (optional) — `sso.tf`
- [x] Tests: `defaults.tftest.hcl`, `compliance.tftest.hcl` — run via `tofu test tests/` (14 pass, incl. mandatory-tags SCP)
- [ ] **Member accounts** — reference note: `accounts.tf` resources are commented out by design. A team **cloning** this landing zone uncomments them with their own email aliases (9 accounts per SCP-DESIGN) and applies against their real org. Not applied in this repo.
- [ ] Add `prod.tftest.hcl` to bootstrap (only defaults + compliance currently)
- [ ] Verify SCP JSON files match the approved 9 SCPs in SCP-DESIGN (filenames differ — confirm semantics align)

### 1.3 Baseline terraservice (`landing-zone/baseline/`)
- [x] Immutable audit bucket (Object Lock COMPLIANCE, 2557-day, KMS, versioning, SecureTransport deny, `prevent_destroy`) — `audit-bucket.tf`
- [x] Audit KMS key — `audit-bucket.tf`
- [x] Org CloudTrail → audit S3 + CloudWatch — `cloudtrail.tf`
- [x] AWS Config recorder + delivery channel — `config.tf`
- [x] GuardDuty + Security Hub delegation — `security-hub-guardduty.tf`
- [x] `deploy-role` module wiring (opentofu-deploy CI/CD role) — `main.tf`
- [x] Docker-less gating via `log_archive_account_id` / `security_account_id` (null = skip)
- [x] Tests: `defaults.tftest.hcl`
- [ ] Add `compliance.tftest.hcl` (audit bucket Object Lock + retention gate) to baseline
- [ ] Add `prod.tftest.hcl` to baseline

---

## 2. Modules (aws)

Gate per module: `main/variables/outputs/locals/versions` + `tests/` + `README.md` + `examples/` + `policies/*.rego`. P0/P1/P2 priorities from `REQUIREMENTS.md §4`.

### 2.1 P0 — core
**`modules/aws/kms-key`** — near complete
- [x] main / variables / outputs / locals / versions
- [x] README.md · examples/basic-usage · tests/{defaults,prod,compliance}
- [ ] `policies/` OPA rego (optional; no `policies/` dir yet)

**`modules/aws/s3-bucket`** — near complete
- [x] main / variables / outputs / locals / versions
- [x] README.md · examples/basic-usage · tests/{defaults,audit,compliance}
- [ ] `policies/` OPA rego (optional)

**`modules/aws/vpc`** — complete (finished this session)
- [x] main / variables / outputs / locals / versions
- [x] tests/{defaults,prod,compliance}.tftest.hcl — 16 assertions pass
- [x] README.md
- [x] examples/basic-usage
- [ ] `policies/` OPA rego (optional)

**`modules/aws/deploy-role`** — complete (this session)
- [x] main / variables / outputs / versions + README.md
- [x] tests/{defaults,prod,compliance}.tftest.hcl — 17 pass
- [x] examples/basic-usage
- [ ] `policies/` OPA rego (optional) — deliberately skipped: scope policy uses scoped `Resource=["*"]` that would false-positive; documented in README

**Not yet created (from REQUIREMENTS §4 P0):**
- [x] `modules/aws/iam-role` — used by all environment `iam/` terraservices (built this session; 19 tests pass)
- [x] `modules/aws/cross-account-role` — used by all accounts (built this session; 17 tests pass)
- [x] `modules/aws/transit-gateway-attachment` — attaches workload VPC to Network Hub TGW; centralized inspection via `appliance_mode_support` (built this session; 10 tests pass, OPA rego + Checkov clean)
- [x] `modules/aws/vpc-endpoint` — Gateway (S3/DynamoDB, free) + Interface (SSM/STS/KMS/etc., multi-AZ) private endpoints (built this session; 10 tests pass, OPA rego + Checkov clean)

**Proposed in CLAUDE.md (not in REQUIREMENTS table):**
- [x] `modules/aws/cloudtrail` (Pillars 5, 7, 8) — org/multi-region trail, COMPLIANCE Object Lock audit bucket (7-yr), KMS encryption, log-file validation, CloudWatch stream + ingestion alarm, SecureTransport deny — 18 tests pass, Checkov 50/0/5 (documented skips)
- [ ] `modules/aws/backup-vault` (Pillar 6 — Backup, DR & Deletion Protection)
- [ ] `modules/aws/oidc-identity-provider` (Pillar 2 — Access Control & Least Privilege)
- [ ] `modules/aws/security-hub` (Pillars 5, 9)

### 2.2 P1 — GenAI runtime (from `GENAI-RUNTIME.md`)
- [x] `modules/aws/opensearch-collection` (P1) — vector store/RAG; always-private AOSS VPC endpoint + network policy, KMS CMK encryption policy, retention ≥ 30 (lifecycle precondition), standby replicas — 17 tests pass, Checkov 5/0/0, OPA verified. NOTES: real `aws_opensearchserverless_collection` schema (no `security_config`/`vpc_options`); separate `aws_opensearchserverless_vpc_endpoint`/`security_policy`/`access_policy`/`lifecycle_policy` resources
- [ ] `modules/aws/bedrock-endpoint` (P1) — inference; invocation logging mandatory for phi/pii/financial, guardrail warn in prod (LAST — per user)
- [ ] `modules/aws/bedrock-guardrail` (P1) — content safety / PII / prompt injection; OPA fail on PII-redaction OFF for PHI (LAST — per user)
- [x] `modules/aws/sagemaker-domain` (P1) — private VPC-only SageMaker Studio (never public), KMS-encrypted, least-privilege execution role, default user profile — 15 tests pass, Checkov 15/0/0
- [x] `modules/aws/rds-pgvector` (P1) — Aurora PostgreSQL + pgvector parameter group + RDS Proxy + **cross-region DR (opt-in Aurora Global Cluster, gated to approved regions + PHI-sovereign)** + **snapshot immutability (SnapshotGuard tag + OPA rule denying wildcard snapshot-delete)** — 18 tests pass, Checkov 47/0/4, OPA rego verified against bad/good IAM inputs

_OPA rules + Checkov CKV mappings for each GenAI module are specified in GENAI-RUNTIME.md §4 — carry them into each `policies/` dir._

### 2.3 P2 — compute/data (from REQUIREMENTS §4)
- [x] `modules/aws/ecs-cluster` (P2) — Fargate-first capacity providers, Container Insights, KMS-encrypted task log group, exec sessions, CPU/memory alarms — 15 tests pass, Checkov 10/0/1
- [ ] `modules/aws/ecs-service` (P2)
- [ ] `modules/aws/ecs-service` (P2)
- [ ] `modules/aws/elasticache` (P2)

### 2.4 GCP (future scope per Mission Statement — not planned for initial release)
- [ ] `gcp/audit-logs` (Pillars 5, 7, 8) — *deferred*
- [ ] `gcp/vpc-service-controls` (Pillars 3, 7) — *deferred*

---

## 3. Environments / terraservices

**`environments/` scaffolding started.** Network Hub transit-gateway is built and verified (below); all other accounts/OUs below are **not started**. Structure from `README.md`, `REQUIREMENTS.md §2`, and `STATE-STRATEGY.md`.

### 3.1 Infra-Control-Plane — platform/infra-team shared accounts
- [x] `environments/infra-control-plane/network-hub/transit-gateway/` — the hub TG, **RAM resource share** for cross-account discovery (workload accounts accept the share + look up the TG locally; SSM param kept as same-account/human pointer only), `participants` least-privilege var, KMS CMK on the SSM param (Pillar 1), region + PHI-sovereign gates, `compliance_controls` output, OPA rego (enforces RAM share). 8/8 tests pass, Checkov 4/0/1 (documented skip), rego verified both directions.
- [ ] `environments/infra-control-plane/network-hub/endpoints/` — shared VPC endpoints (S3/DynamoDB gateway + interface), cross-account exposure design pending. Apply-order item 2.
- [ ] `environments/infra-control-plane/shared-tools/compute/`

### 3.2 Production — `/Production/*`
- [ ] `environments/production/platform/{iam,network,data,compute,ai}/`
- [ ] `environments/production/research/{iam,network,data,compute,ai}/`
- [ ] `environments/production/data-platform/{iam,network,data,compute,ai}/`

### 3.3 Pre-Production — `/Pre-Production/*`
- [ ] `environments/preprod/platform/{iam,network,data,compute,ai}/`

### 3.4 Development — `/Development/*`
- [ ] `environments/development/platform/{iam,network,data,compute,ai}/`

### 3.5 Sandbox — `Sandbox` (minimal SCPs)
- [ ] `environments/sandbox/platform/{iam,network}/`

**Layering order after accounts exist (STATE-STRATEGY §4):** bootstrap → baseline → Network Hub (transit gateway + endpoints) → workload terraservices (iam → network/TGWA → data/compute/ai).

---

## 4. Scaffolding skills (`/` commands)

All 7 skills exist and are symlinked from `~/Developer/agents/terraform-agents/` into `.claude/skills/` (`make symlink-skills`). Verify freshness as modules land:
- [x] `/create-module` — module skeleton generator
- [x] `/review-module` — fmt/validate/Checkov/OPA/Infracost + audit checklist
- [x] `/create-workload` — terraservice layer scaffold
- [x] `/add-environment` — new AWS account + business unit directory
- [x] `/add-compliance-gates` — injects standard pillar variable blocks
- [x] `/add-genai-module` — GenAI agentic runtime module scaffold (consumes GENAI-RUNTIME.md)
- [x] `/ci-pipeline` — CI/CD config generation (GitHub Actions, Atlantis, OIDC)

---

## 5. CI / automation

### 5.1 Present
- [x] Tooling Makefile (`fmt-check`, `validate`, `checkov`, `plan`, `opa`, `test`, `infracost`, `review`, `all`, `symlink-skills`, `setup`) — `Makefile`
- [x] GitHub Actions `module-review.yml` — per-module fmt/validate/checkov/opa/test/infracost matrix on PRs touching `modules/**`
- [x] `scripts/setup-dev.sh` — dev tool installer

### 5.2 Missing (from CLAUDE.md §CI/CD & Automation)
- [ ] `.github/CODEOWNERS` — REQUIRES.md §6 specifies the path-based team map; **file absent**
- [ ] Atlantis config (`atlantis.yaml`, `repos.yaml`) — no Atlantis files on disk
- [ ] OIDC federation setup docs / workflow (roles assumed via OIDC only, no static creds) — none present
- [ ] Commit signing enforcement (GPG on `main`, signed tags, branch protection) — no config/docs present
- [ ] Auto-tag/SBOM on merge to main (`vMAJOR.MINOR.PATCH`, changelog from PR titles, SBOM from `tofu providers`) — not wired
- [ ] Drift detection (scheduled `tofu plan`, results to drift channel) — not wired
- [ ] Atlantis workflows for approval gates (dev single-approve auto-apply, staging infra-approve, prod dual-approve) — not wired
- [ ] Infracost on every PR (Atlantis integration) — only module-review workflow currently

---

## 6. Compliance verification gates

Per-module (and terraservice) gates defined in `CLAUDE.md` — run before release:
- [x] `tofu fmt -check` wired into CI (module-review)
- [x] `tofu validate` wired into CI
- [x] Checkov (fail HIGH/CRITICAL) wired into CI
- [x] OPA eval (Rego) wired into CI **only where `policies/` exists** — add policies dirs to each module
- [x] Infracost breakdown wired into CI (module-review)
- [ ] Full `tofu test` across all modules (kms-key + s3-bucket pass; vpc/deploy-role need tests first)
- [ ] Audit checklist (CLAUDE.md Module Audit Checklist) confirmed per module before release

---

## Status summary

| Area | Complete | Outstanding |
|---|---|---|
| Landing zone — reference docs | 4/4 | — |
| Landing zone — bootstrap | core complete | member accounts, prod test, SCP filename audit |
| Landing zone — baseline | core complete | compliance + prod tests |
| Modules P0 (kms, s3) | near-complete | regos (deferred — documented layered model) |
| Modules P0 (vpc, deploy-role) | vpc + deploy-role complete | regos |
| Modules P0 (iam-role, cross-account-role, TGW-attach, vpc-endpoint) | all P0 modules now built | none — P0 complete |
| SCP catalog | 9 SCPs incl. EnforceMandatoryTags | — |
| Modules P1 (GenAI) | rds-pgvector, opensearch-collection, sagemaker-domain complete (each verified: tests + Checkov + OPA) | Bedrock (endpoint + guardrail) LAST — per user |
| Modules P2 (compute/audit) | ecs-cluster, cloudtrail complete | ecs-service (next), backup-vault, oidc-identity-provider, security-hub |
| Environments / terraservices | `infra-control-plane/network-hub/transit-gateway` (hub TG + RAM share for cross-account discovery, SSM as same-account pointer; 8 tests pass, Checkov/OPA clean) | `network-hub/endpoints`; then reference dev+prod workload pair (`iam` → `network` accepts RAM share + looks up TG locally → `data`/`compute`/`ai`) |
| Skills | 7/7 built | re-verify after modules land |
| CI | checkov/opa/test/infracost workflow | CODEOWNERS, Atlantis, OIDC, signing, drift, tag/SBOM |
| Persona & positioning | persona in CLAUDE.md + README; greenfield/adopt flags in bootstrap & baseline | build the adoption path guide for existing-org teams |