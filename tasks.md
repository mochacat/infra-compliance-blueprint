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
- [x] Organization + OU structure + 10 SCPs + SSO
- [x] Tests: `defaults.tftest.hcl`, `compliance.tftest.hcl` (14 pass)
- [ ] Member accounts — reference note: commented out by design
- [ ] Add `prod.tftest.hcl` to bootstrap
- [ ] Verify SCP JSON files match the approved 10 SCPs in SCP-DESIGN

### 1.3 Baseline terraservice (`landing-zone/baseline/`)
- [x] Immutable audit bucket, KMS key, CloudTrail, Config, GuardDuty, Security Hub, deploy-role
- [x] Tests: `defaults.tftest.hcl`
- [ ] Add `compliance.tftest.hcl` (audit bucket Object Lock + retention gate)
- [ ] Add `prod.tftest.hcl`

---

## 2. Modules (aws)

### 2.1 P0 — core (complete)
- [x] kms-key — built, tested, README'd
- [x] s3-bucket — built, tested, README'd
- [x] vpc — built, 16 tests pass, README'd
- [x] deploy-role — built, 17 tests pass, README'd
- [x] iam-role — built, 19 tests pass, README'd
- [x] cross-account-role — built, 17 tests pass, README'd
- [x] transit-gateway-attachment — built, 10 tests pass, OPA rego, Checkov clean
- [x] vpc-endpoint — built, 10 tests pass, OPA rego, Checkov clean
- [x] cloudtrail — built, 18 tests pass, Checkov 50/0/5

**Still missing (from CLAUDE.md proposals):**
- [ ] `modules/aws/backup-vault` (Pillar 6)
- [ ] `modules/aws/oidc-identity-provider` (Pillar 2)
- [ ] `modules/aws/security-hub` (Pillars 5, 9)

### 2.2 P1 — GenAI runtime (complete)
- [x] opensearch-collection — 17 tests pass, Checkov 5/0/0, OPA verified
- [x] sagemaker-domain — 15 tests pass, Checkov 15/0/0
- [x] rds-pgvector — 18 tests pass, Checkov 47/0/4, OPA verified
- [ ] bedrock-endpoint (deferred — LAST per user)
- [ ] bedrock-guardrail (deferred — LAST per user)

### 2.3 P2 — compute/data
- [x] ecs-cluster — 15 tests pass, Checkov 10/0/1
- [ ] ecs-service
- [ ] elasticache

### 2.4 GCP (future scope — deferred)

---

## 3. Environments / terraservices

### 3.1 Infra-Control-Plane
- [x] `network-hub/transit-gateway/` — hub TG + RAM share + SSM pointer. 8 tests pass, Checkov/OPA clean.
- [x] `network-hub/network/` — hub VPC (RFC-6598), TGW attachment, VPC endpoints, route tables, SSM publication. Replaces `endpoints/`. 6 defaults pass + 3 compliance gates verified.
- [ ] `shared-tools/compute/`

### 3.2 Development / Platform — FIRST REFERENCE WORKLOAD (this PR)
**Scaffolded (boilerplate, ready for customization):**
- [x] `iam/` — 4 IAM roles (ecs-task-exec, ecs-service, sagemaker-exec, rds-proxy + dev KMS key)
  - [x] variables.tf, locals.tf, main.tf, outputs.tf, versions.tf
  - [x] README.md — with blast radius table and dependency explanation
  - [x] tests/defaults.tftest.hcl, tests/compliance.tftest.hcl
  - [x] policies/iam.rego
- [x] `network/` — VPC (3 tiers × 2 AZs), TGW attachment, route tables with TGW default route, VPC endpoints (gateway + interface)
  - [x] variables.tf, locals.tf, main.tf, outputs.tf, versions.tf
  - [x] README.md — with blast radius table
  - [x] tests/defaults.tftest.hcl
  - [x] policies/network.rego
- [x] `data/` — Aurora pgvector + OpenSearch Serverless (dev-sized: serverless, no standby replicas)
  - [x] variables.tf, locals.tf, main.tf, outputs.tf, data.tf, versions.tf
  - [x] README.md — with blast radius table and remote state contract
  - [x] tests/defaults.tftest.hcl
  - [x] policies/data.rego
- [x] `compute/` — ECS cluster (Fargate-only, dev-sized)
  - [x] variables.tf, locals.tf, main.tf, outputs.tf, data.tf, versions.tf
  - [x] README.md — with blast radius table
  - [x] tests/defaults.tftest.hcl
  - [x] policies/compute.rego
- [x] `ai/` — SageMaker Studio domain (VpcOnly, ml.t3.medium, Bedrock deferred)
  - [x] variables.tf, locals.tf, main.tf, outputs.tf, data.tf, versions.tf
  - [x] README.md — with blast radius table
  - [x] tests/defaults.tftest.hcl
  - [x] policies/ai.rego
- [x] Platform-level README.md — explains the layering model, safety, blast radius, and why not one big state

**Customization checklist for the team cloning this reference:**
- [x] DB credentials now use `manage_master_user_password = true` (RDS-managed) — no manual secret needed
- [x] OpenSearch `iam.principal_arns` reads compute/ai role ARNs via SSM — no manual fill-in needed
- [x] SSM paths now use `${var.business_unit}` instead of hardcoded `"platform"` — set `business_unit` per environment
- [x] Each environment/BU has a unique VPC CIDR (no overlaps)
- [x] Hub network's `spoke_cidrs` default now lists all known spoke CIDRs
- [ ] Add a `data` source or appropriate lookup for `flow_log_destination.bucket_arn` — read from the baseline terraservice's remote state or a central config store
- [ ] Uncomment Bedrock modules in `ai/main.tf` when ready
- [ ] Adjust `region` and `subnets.availability_zones` to match your target region
- [ ] Adjust `vpc_cidr` and `reserved_cidrs` to fit your IPAM plan
- [ ] Adjust the `data.aws_ram_resource_share` name filter in `network/data.tf` to match your hub TG share name

### 3.3 Production — `/Production/*`
- [x] `environments/production/platform/{iam,network,data,compute,ai}/` — cloned from dev/platform, prod CIDR 10.20.0.0/16
- [x] `environments/production/research/{iam,network,data,compute,ai}/` — cloned from dev/platform, research CIDR 10.21.0.0/16
- [x] `environments/production/data-platform/{iam,network,data,compute,ai}/` — cloned from dev/platform, data-platform CIDR 10.22.0.0/16

### 3.4 Pre-Production — `/Pre-Production/*`
- [x] `environments/preprod/platform/{iam,network,data,compute,ai}/` — cloned from dev/platform, preprod CIDR 10.10.0.0/16

### 3.5 Development — `/Development/*`
- [x] `environments/development/research/{iam,network,data,compute,ai}/` — cloned from dev/platform, research CIDR 10.1.0.0/16

### 3.6 Sandbox — `Sandbox` (minimal SCPs)
- [x] `environments/sandbox/platform/{iam,network}/` — cloned from dev/platform (iam + network only), sandbox CIDR 10.255.0.0/16

---

## 4. Skills (`/` commands)

All 7 skills exist and are symlinked:
- [x] `/create-module`, `/review-module`, `/create-workload`, `/add-environment`, `/add-compliance-gates`, `/add-genai-module`, `/ci-pipeline`

---

## 5. CI / automation

### 5.1 Present
- [x] Makefile (`fmt-check`, `validate`, `checkov`, `plan`, `opa`, `test`, `infracost`, `review`, `all`, `symlink-skills`, `setup`, `opa-ssm`, `ssm-contract-json`)
- [x] GitHub Actions `module-review.yml` — per-module review on PRs touching `modules/**`
- [x] GitHub Actions `env-review.yml` — per-terraservice review on PRs touching `environments/**` (includes SSM contract OPA check)
- [x] `policies/ssm-contract.rego` — OPA rule preventing SSM parameter removal with downstream consumers
- [x] `scripts/setup-dev.sh` — dev tool installer
- [x] `scripts/check-downstream.sh` — Atlantis plan-time downstream layer dependency warning
- [x] `scripts/check-ssm-drift.sh` — Atlantis pre-apply SSM parameter existence check (enforces apply ordering)

### 5.2 Missing
- [x] `.github/CODEOWNERS` — infra-team, platform-team, genai-team, data-team, research-team, @cat (admin)
- [x] Atlantis config (`atlantis.yaml` — 37 projects, 3 workflows, workflow_mode: multi)
- [x] `docs/repos.yaml` — server-level config reference (repo allowlist, OIDC, IAM policy)
- [x] `docs/atlantis-setup.md` — OIDC setup, webhook config, SSM permissions, state backend, OPA install
- [ ] OIDC federation setup docs / workflow
- [ ] Commit signing enforcement (GPG, signed tags, branch protection)
- [ ] Auto-tag/SBOM on merge to main
- [ ] Drift detection (scheduled `tofu plan`)
- [ ] Infracost on every PR (Atlantis integration)
- [x] `ssm-contract.yaml` — dependency graph for PR review, enforced via OPA at plan time
- [x] SCP 10 (ProtectSSMParameters) — restrict SSM write/delete to Atlantis role only

---

## 6. Compliance verification gates

- [x] `tofu fmt -check` wired into CI
- [x] `tofu validate` wired into CI
- [x] Checkov (fail HIGH/CRITICAL) wired into CI
- [x] OPA eval wired into CI (where `policies/` exists)
- [x] Infracost breakdown wired into CI
- [ ] Full `tofu test` across all modules
- [ ] Audit checklist confirmed per module before release

---

## Status summary

| Area | Complete | Outstanding |
|---|---|---|
| Landing zone — SCPs | 10/10 designed, 10/10 deployed | SCP 10 (ProtectSSMParameters) added |
| Landing zone — reference docs | updated (SCP 10) | — |
| Landing zone — bootstrap | core complete | member accounts, prod test, SCP audit |
| Landing zone — baseline | core complete | compliance + prod tests |
| All modules P0–P2 (14 modules) | 14 built, tested, README'd | bedrock (deferred), ecs-service, elasticache, backup-vault, oidc-idp, security-hub |
| **Environments / terraservices** | **8 BUs scaffolded (dev/plat, dev/research, preprod/plat, prod/plat, prod/research, prod/data-platform, sandbox/plat, infra-cp/network-hub)** | **customization items per env** |
| Skills | 7/7 built | re-verify after modules land |
| CI | checkov/opa/test/infracost workflow, CODEOWNERS, Atlantis config | OIDC, signing, drift, tag/SBOM |
