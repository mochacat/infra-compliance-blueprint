# CLAUDE.md — Anestoa Infrastructure Modules

> Build OpenTofu modules for **AWS** infrastructure in regulated environments running AI/LLM
> workloads — insurtech, healthtech, and fintech requiring **HIPAA** and **SOC 2 Type II** compliance.
>
> Every module is **compliant by default**: opt out of a security control, don't opt in.
> Every module supports **AI workload patterns** — vector databases, GPU compute, training data pipelines.
>
> Best-fit user: **early-stage technical teams (pre-seed founders → Series A/B)** in regulated
> verticals that must be compliant *before* they have dedicated infra headcount. They start with a
> management account and informal logging, and need a controlled, auditable AWS org built correctly
> the first time.
>
> This is a **reference monorepo**: `modules/` are real, tested, reusable building blocks; the
> landing zone, environment scaffolding, and CI/CD wiring are reproducible patterns to clone and
> adapt to a specific AWS organization. Clone, keep what fits, swap the company-specific details.

---

## Build Status

The canonical, living build checklist lives in [`tasks.md`](tasks.md) at the repo root.
It tracks every outstanding module, terraservice, SCP, CI hook, and GenAI component
against the pillars. Update it on every PR — check items off as they merge.

---

## Core Philosophy: Shift Left Everything

Security, compliance, and cost are enforced at the **earliest possible layer** — not
inspected after deployment. Every module, SCP, and pipeline is designed so that
mistakes are prevented, not detected.

| Layer | What shifts left | How |
|---|---|---|
| **Module defaults** | Security + compliance | KMS required, private subnets, no public IPs, deletion protection on. Opt *out*, not in. |
| **SCPs (organizational)** | Security + compliance | Unencrypted resources denied. Public access denied. Root user actions denied. |
| **OPA (plan time)** | Compliance + policy | Every plan evaluated against HIPAA/SOC 2 rules before apply. Violations block the PR. |
| **Checkov (CI)** | Compliance | Module code scanned for misconfigurations before merge. |
| **Infracost (PR time)** | FinOps | Every change includes a cost estimate. No bill shock at month end. |
| **Git (PR flow)** | Audit + change mgmt | Every change has a paper trail. Atlantis enforces approval gates. |
| **`tofu test` (unit)** | Correctness | Compliance assertions tested in CI. A module that passes tests is known-compliant. |

**Design principle:** A developer should not be able to create a non-compliant
resource even if they try. If a control can be enforced in a module default,
do it there. If it can be enforced in an SCP, do it there too. Defense in depth.

---

## Mission Statement

This repository produces shared, versioned infrastructure modules that enforce compliance controls
by default across all ten pillars. It is designed as a reference implementation of a controlled,
auditable AWS platform for regulated early-stage companies. The `modules/` are the consumable
product (via `source = "git::..."?ref=vX.Y.Z"`); the landing zone and environment scaffolding are
reproducible patterns that a team clones and adapts to its own organization. This enables a small
team to hold a compliance posture it could not otherwise maintain.

**Engine:** OpenTofu (primary). Terraform-compatible by convention — same HCL, no Tofu-only language features.
No Terraform Cloud / Enterprise lock-in. No per-user license costs.

**Cloud:** AWS only (MVP). GCP modules are future scope, not planned for initial release.

**Compliance target:** Every module is auditable against HIPAA and SOC 2 Type II when deployed
with the default posture. FDA 21 CFR Part 11 and PCI-DSS are future additions.

---

## Module Requirements (Compliance Pillars)

Every shared module must satisfy all applicable sections below. These are gating criteria for PR
merge. Each pillar defines a **standard variable interface**, **defaults & validations**, hard
**must / must-not** rules, **Checkov/OPA enforcement**, and a **`tofu test` assertion**.

---

### Pillar 1: Encryption — At Rest and In Transit

Every stateful resource uses a **caller-provided KMS key** for encryption at rest. TLS ≥ 1.2 is
enforced for all in-transit communication. The module never creates its own key or offers an
"encryption disabled" toggle.

```hcl
# AWS — present in every stateful module
variable "kms_key_arn" {
  description = "CMK ARN for encryption at rest. Module does NOT create a key."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "Must be a valid KMS key ARN."
  }
}

# GCP variant
variable "kms_key_name" {
  description = "CMEK resource name (projects/.../locations/.../keyRings/.../cryptoKeys/...)"
  type        = string
  nullable    = false
}
```

| Must | Must not |
|---|---|
| Accept `kms_key_arn` / `kms_key_name` in every stateful module | Create its own KMS key |
| Set `ssl_protocols = ["TLSv1.2", "TLSv1.3"]` on listeners | Offer an encryption-disabled toggle |
| Set `viewer_protocol_policy = "https-only"` on CDNs | Default to AES256 / SSE-S3 |
| Add `aws:SecureTransport = false` deny to S3 bucket policies | Allow TLS 1.0 / 1.1 |
| Enable `require_ssl` on RDS parameter groups / Cloud SQL | |

**Checkov:** CKV_AWS_33, CKV_AWS_145, CKV_AWS_158, CKV_GCP_6

**OPA:** Fail if `aws_s3_bucket` has no `kms_master_key_id`. Fail if listener allows TLS < 1.2.

**`tofu test`:**
```hcl
run "test_encryption_cmk_required" {
  command = plan
  assert {
    condition = aws_s3_bucket.this.server_side_encryption_configuration[0].rule[0].apply_server_side_encryption_by_default[0].kms_master_key_id != null
    error_message = "Must use KMS CMK"
  }
}
```

---

### Pillar 2: Access Control & Least Privilege

Every module that creates IAM roles, service accounts, or resource policies scopes permissions to
the minimum required. No wildcard resources, no broad managed policies, no shared service roles.

```hcl
variable "iam" {
  description = "IAM configuration"
  type = object({
    role_name_prefix         = optional(string, "app-")
    principal_arns           = list(string)
    additional_policy_arns   = optional(list(string), [])
    permissions_boundary_arn = optional(string, null)
  })
  nullable = false
}
```

| Must | Must not |
|---|---|
| Create a dedicated role per resource | Reuse a shared service role |
| Accept and apply `permissions_boundary_arn` | Attach AdministratorAccess / PowerUserAccess |
| Scope every policy statement to a specific ARN | Use `"*"` in `Resource` or `Action` |
| Tag all roles `Resource`, `Environment` | Hardcode a principal |

**Checkov:** CKV_AWS_63, CKV_AWS_111, CKV_GCP_76

**OPA:** Fail if `Resource = "*"` in any IAM policy. Fail if roles lack a permissions boundary.

**`tofu test`:** assert `data.aws_iam_policy_document.this` contains no `"*"` resource.

---

### Pillar 3: Network Security & Isolation

Zero public exposure by default. Resources place in private subnets, behind load balancers or
private endpoints. Public access is an explicit, documented opt-in.

```hcl
variable "network" {
  description = "Network placement"
  type = object({
    vpc_id          = string
    subnet_ids      = list(string)
    private_only    = optional(bool, true)
    allowed_cidrs   = optional(list(string), [])
    public_ip       = optional(bool, false)
    vpc_endpoint_id = optional(string, null)
  })
  nullable = false
  validation {
    condition     = var.network.private_only == true ? var.network.public_ip == false : true
    error_message = "public_ip must be false when private_only is true."
  }
}
```

| Must | Must not |
|---|---|
| Default `private_only = true` | Assign public IPs to DB / cache / queue |
| Place resources in private subnets | Allow ingress `0.0.0.0/0` by default |
| Restrict egress to what the resource needs | Use `protocol = "-1"` on ingress |
| Support `vpc_endpoint_id` for PrivateLink | |

**Checkov:** CKV_AWS_2, CKV_AWS_8, CKV_AWS_20, CKV_GCP_2, CKV_GCP_6

**OPA:** Fail if any ingress rule `cidr_blocks` contains `0.0.0.0/0`.

**`tofu test`:** assert no ingress rule uses `0.0.0.0/0`.

---

### Pillar 4: High Availability & Region Control

Multi-AZ by default. Resources only deploy in approved regions. Single-AZ and cross-region
replication are explicit opt-ins with compliance gates.

```hcl
variable "allowed_regions" {
  description = "Approved regions. Rejected at plan time if outside this list."
  type        = list(string)
  nullable    = false
  default     = ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"]
}

variable "region" {
  description = "Target region. Must be in allowed_regions."
  type        = string
  nullable    = false
  validation {
    condition     = contains(var.allowed_regions, var.region)
    error_message = "Region must be in allowed_regions."
  }
}

variable "high_availability" {
  description = "Availability configuration"
  type = object({
    multi_az                    = optional(bool, true)
    az_override                 = optional(string, null)
    cross_region_replica        = optional(bool, false)
    cross_region_replica_region = optional(string, null)
  })
  nullable = false
  validation {
    condition     = var.high_availability.cross_region_replica == true ? contains(var.allowed_regions, var.high_availability.cross_region_replica_region) : true
    error_message = "Replica target must be in allowed_regions."
  }
}
```

| Must | Must not |
|---|---|
| Default `multi_az = true` on all regional resources | Hardcode regions |
| Validate `region` against `allowed_regions` | Default to single-AZ |
| Reject `multi_az = false` when `environment = "prod"` | Replicate cross-region without approval |
| Spread compute across all AZs in region | Cross-region to an unapproved region |

**Checkov:** CKV_AWS_139, CKV_AWS_150, CKV_AWS_43

**OPA:** Fail if `multi_az = false` in prod. Fail if region not in allowed_regions.

**`tofu test`:** assert `multi_az == true` by default; `expect_failures` on an unapproved region.

---

### Pillar 5: Observability — Alerting, Logging & Monitoring

Every resource ships logs and metrics to **centralized destinations** provided by the caller. No
resource exists in the dark — logs go to a SIEM, metrics trigger alarms, security findings fire to
a dedicated topic.

```hcl
variable "observability" {
  description = "Centralized observability destinations"
  type = object({
    log_group_name              = optional(string, null)
    log_retention_days          = optional(number, 90)
    s3_log_bucket_arn           = optional(string, null)
    alarm_topic_arn             = optional(string, null)
    security_findings_topic_arn = optional(string, null)
    detailed_monitoring         = optional(bool, true)
  })
  nullable = false
}
```

| Must | Must not |
|---|---|
| Ship logs to `s3_log_bucket_arn` (immutable destination) | Create its own SNS topic / log bucket |
| `log_retention_days ≥ 30` | Set retention below 30 days |
| Create default CloudWatch alarms per resource type | Skip alarm creation |
| Enable detailed (1-min) monitoring on compute | |
| Accept `security_findings_topic_arn` for Security Hub routing | |

**Checkov:** CKV_AWS_33, CKV_AWS_35, CKV_AWS_68, CKV_AWS_73, CKV_AWS_149

**OPA:** Fail if `log_retention_days < 30`. Fail if `alarm_topic_arn` is null in prod.

**`tofu test`:** assert at least one default alarm exists.

---

### Pillar 6: Backup, DR & Deletion Protection

Every stateful resource has a minimum 30-day retention policy, deletion protection enabled, and
optional cross-region DR that is opt-in only.

```hcl
variable "backup" {
  description = "Backup, retention, and deletion protection"
  type = object({
    retention_days        = optional(number, 30)
    deletion_protection   = optional(bool, true)
    skip_final_snapshot   = optional(bool, false)
    cross_region_replica  = optional(bool, false)
    replica_region        = optional(string, null)
    replica_kms_key_arn   = optional(string, null)
  })
  nullable = false
  validation {
    condition     = var.backup.retention_days >= 30
    error_message = "Minimum retention is 30 days."
  }
  validation {
    condition     = var.backup.deletion_protection == true ? true : can(regex("^(dev|test)$", var.environment))
    error_message = "deletion_protection must be true outside dev/test."
  }
}
```

| Must | Must not |
|---|---|
| Default `deletion_protection = true` | `deletion_protection = false` in prod |
| Default `retention_days = 30` | Allow `retention_days < 30` |
| Require `skip_final_snapshot = false` in prod | Replicate across regions without approval |
| Enable S3 versioning + Object Lock on log buckets | |

**Checkov:** CKV_AWS_28, CKV_AWS_129, CKV_AWS_157, CKV_AWS_166

**OPA:** Fail if `deletion_protection = false` in prod. Fail if `skip_final_snapshot = true` in prod.

**`tofu test`:** assert `deletion_protection == true` by default; `expect_failures` on `retention_days = 14`.

---

### Pillar 7: Data Residency & Sovereignty

Every module that handles data must be told its **classification level**. PHI and financial data
carry strict residency constraints; cross-border movement requires a compliance approval reference.

```hcl
variable "data_classification" {
  description = "Data classification: internal, pii, phi, financial, cardholder"
  type        = string
  nullable    = false
  default     = "internal"
  validation {
    condition     = contains(["internal", "pii", "phi", "financial", "cardholder"], var.data_classification)
    error_message = "Must be one of: internal, pii, phi, financial, cardholder."
  }
}

variable "data_residency" {
  description = "Data residency constraints"
  type = object({
    sovereign_only                   = optional(bool, false)
    jurisdiction                     = optional(string, null)
    allow_cross_border_replication   = optional(bool, false)
    cross_border_approval_ref        = optional(string, null)
    business_associate_agreement_req = optional(bool, false)
  })
  nullable = false
  # PHI requires sovereign only
  validation {
    condition     = (var.data_classification != "phi" || var.data_residency.sovereign_only == true)
    error_message = "PHI requires sovereign_only = true."
  }
  # Cross-border needs ticket reference
  validation {
    condition     = (!var.data_residency.allow_cross_border_replication || var.data_residency.cross_border_approval_ref != null)
    error_message = "Cross-border replication requires approval_ref."
  }
}
```

| Must | Must not |
|---|---|
| Require `data_classification` on all data resources | Default to permissive classification |
| Set `sovereign_only = true` when `classification = "phi"` | Allow cross-region replication for PHI |
| Gate cross-border replication with `cross_border_approval_ref` | Replicate without approval ticket |
| Tag resources with `DataClassification`, `Jurisdiction` | Hardcode jurisdiction |

**OPA:** Fail if PHI data has cross-region replication. Fail if cross-border lacks approval ref.

**`tofu test`:** `expect_failures` on PHI with `cross_region_replica = true`.

---

### Pillar 8: Auditability & Immutability

Every S3 bucket that stores audit logs has Object Lock in COMPLIANCE mode with a minimum
7-year retention. Versioning is always enabled on state and log buckets.

```hcl
variable "audit_lock_mode" {
  description = "Object Lock mode: COMPLIANCE or GOVERNANCE"
  type        = string
  default     = "COMPLIANCE"
  validation {
    condition     = contains(["COMPLIANCE", "GOVERNANCE"], var.audit_lock_mode)
    error_message = "Must be COMPLIANCE or GOVERNANCE."
  }
}

variable "audit_retention_days" {
  description = "Log retention in days. Minimum 2557 (7 years)."
  type        = number
  default     = 2557
  validation {
    condition     = var.audit_retention_days >= 2557
    error_message = "Minimum audit retention is 2557 days (7 years)."
  }
}
```

| Must | Must not |
|---|---|
| Enable `object_lock_enabled = true` on all log buckets | Create log buckets without Object Lock |
| Default `audit_lock_mode = "COMPLIANCE"` | Use GOVERNANCE mode in prod |
| Default `audit_retention_days = 2557` | Allow early deletion bypass |
| Enable versioning on all state + log buckets | Suspend versioning on audit buckets |

**Checkov:** CKV_AWS_33, CKV_AWS_35, CKV_AWS_166

**OPA:** Fail if Object Lock not enabled. Fail if COMPLIANCE not used in prod.

**`tofu test`:** assert Object Lock mode is COMPLIANCE by default; `expect_failures` on short retention.

---

### Pillar 9: Change Management & Policy Enforcement

Every infrastructure change flows through **Atlantis** with OPA evaluation, approval gates, and a
complete audit trail. This is enforced at the platform (CI) layer, but modules expose the
information Atlantis needs to evaluate policy.

```hcl
variable "environment" {
  description = "Environment: dev, test, staging, prod, preprod, sandbox, commercial"
  type        = string
  nullable    = false
  validation {
    condition     = contains(["dev", "test", "staging", "prod", "preprod", "sandbox", "commercial"], var.environment)
    error_message = "Must be one of: dev, test, staging, prod, preprod, sandbox, commercial."
  }
}

output "compliance_controls" {
  description = "Compliance state for OPA evaluation"
  value = {
    environment         = var.environment
    deletion_protection = var.backup.deletion_protection
    encryption_at_rest  = var.kms_key_arn != null
    retention_days      = var.backup.retention_days
    multi_az            = var.high_availability.multi_az
  }
}
```

**Atlantis workflow (platform layer):**
- Dev/test: single approval, auto-apply
- Staging: infra team must approve
- Production: dual approval required, no direct applies

**OPA:** Fail if prod lacks ≥ 2 approvals. Fail if destruction lacks a change ticket.

**`tofu test`:** assert `compliance_controls` output reflects `environment`.

---

### Pillar 10: FinOps & Cost Controls

Every module defaults to **cost-conscious sizing** and enforces cost allocation tags. Infracost
runs on every PR. Non-production resources can opt into auto-shutdown.

```hcl
variable "cost_controls" {
  description = "Cost management settings"
  type = object({
    budget_amount           = optional(number, null)
    budget_alert_thresholds = optional(list(number), [50, 80, 100])
    budget_email            = optional(string, null)
    instance_size           = optional(string, null)
    shutdown_outside_hours  = optional(bool, false)
    cost_center             = optional(string, null)
    project_code            = optional(string, null)
  })
  nullable = true
}
```

| Must | Must not |
|---|---|
| Default to small/burstable instance types | Default to largest instance size |
| Tag all resources `CostCenter`, `Project`, `Environment` | Create resources without cost tags |
| Create budget alarms when `budget_amount` set | `shutdown_outside_hours = true` in prod |
| Integrate with Infracost at the Atlantis level | |

**OPA:** Fail if `CostCenter` tag missing in prod. Fail if oversized instance in non-prod.

**`tofu test`:** assert `CostCenter` tag present.

---

## Module SDK & Delivery Platform


### Repository Layout

The repo is organized around AWS Organizations OUs. Each environment + business unit
combination is one AWS account under `environments/`. The OU path is derivable from
the directory path.

```
infrastructure/                          # Cloned per client
│
├── landing-zone/                        # Infra team — control plane
│   ├── bootstrap/                       # Org, OUs, SCPs, accounts
│   ├── baseline/                        # CloudTrail, GuardDuty, S3, roles
│   └── reference/                       # Design documents
│
├── environments/                        # Every AWS account in the org
│   ├── infra-control-plane/             # Platform/infra-team shared control plane
│   │   │                                # OU: /Infra-Control-Plane/*
│   │   ├── network-hub/                 # Transit Gateway, shared endpoints
│   │   │   ├── transit-gateway/
│   │   │   └── endpoints/
│   │   └── shared-tools/
│   │       └── compute/
│   │
│   ├── production/                      # OU: /Production/*
│   │   ├── platform/                    # Business unit: Platform
│   │   │   ├── iam/
│   │   │   ├── network/                 # Creates VPC + TGWA to hub
│   │   │   ├── data/
│   │   │   ├── compute/
│   │   │   └── ai/
│   │   ├── research/
│   │   │   └── (same terraservices)
│   │   └── data-platform/
│   │       └── (same terraservices)
│   │
│   ├── preprod/                         # OU: /Pre-Production/*
│   │   └── platform/
│   │       └── (same terraservices)
│   │
│   ├── development/                     # OU: /Development/*
│   │   └── platform/
│   │       └── (same terraservices)
│   │
│   └── sandbox/                         # OU: Sandbox
│       └── platform/
│           ├── iam/
│           └── network/
│
├── modules/                             # Reusable building blocks
│   ├── vpc/
│   ├── s3-bucket/
│   ├── kms-key/
│   ├── iam-role/
│   ├── transit-gateway-attachment/
│   ├── vpc-endpoint/
│   ├── rds-instance/
│   ├── ecs-cluster/
│   ├── sagemaker-domain/
│   ├── bedrock-endpoint/
│   ├── ec2-gpu/
│   └── cross-account-role/
│
├── .github/CODEOWNERS
├── CLAUDE.md
├── Makefile
└── README.md
```

**Key naming rules:**
- Directories are named after what they do (`iam/` not `terraservice-iam`)
- Accounts are named `<environment>-<business-unit>` (e.g., `production-platform`, `dev-research`)
- The OU path is derivable: `environments/production/platform/` -> OU `/Production/Platform`
- State key matches the path: `environments/production/platform/network.tfstate`


### Directory Layout (every module)

```
modules/<cloud>/<name>/
├── main.tf                  # Primary resource definitions
├── variables.tf             # All variables + descriptions + validations
├── outputs.tf               # All outputs + descriptions
├── locals.tf                # Computed values, naming, tags
├── data.tf                  # Data sources only
├── versions.tf              # Provider requirements + tofu version
├── README.md                # Purpose, usage, variables, outputs, pillar compliance
├── policies/                # OPA rules scoped to this module
│   └── <name>.rego
└── tests/
    ├── defaults.tftest.hcl      # Plan with defaults
    ├── prod.tftest.hcl          # Plan with prod-grade inputs
    ├── compliance.tftest.hcl    # expect_failures on compliance gates
    └── fixtures/                # Test-only .tf files
```

### Module Boundaries

- **One resource type per module.** A module called `s3-bucket` creates only S3 buckets. If you
  need another resource type, create another module. Keeps testing simple, versioning independent,
  review scoped.
- **Modules are not appliances.** Don't build a module that provisions an entire environment.
  Compose modules in the `environments/<env>/<business-unit>/<layer>/` directories.

### Testing Strategy

| Layer | Tool | Coverage |
|-------|------|----------|
| Unit | `tofu test` (`.tftest.hcl`) | All modules, pre-merge |
| Integration | `tofu test` (`.tftest.hcl`, multi-run or setup/teardown) | Optional smoke, isolated accounts |
| Policy | Checkov + OPA (Rego) | Every plan in CI |

- Tests runnable locally: `tofu test ./tests/`.
- **No Go / Terratest dependency** — everything is OpenTofu-native.

### Static Analysis & Policy-as-Code

Run on every PR / plan:
1. `tofu fmt -check` — formatting
2. `tofu validate` — validity
3. `checkov --framework terraform` — fail on HIGH/CRITICAL
4. `opa eval` against plan JSON — custom org policies
5. `infracost breakdown --path .` — cost estimate on every PR

### CI/CD & Automation

- **Atlantis only** (no other runners). Infra team is the sole audience for modules.
- **PR workflow**: plan → static analysis → test → apply (with approval).
- **Authentication**: all roles assumed via OIDC federation from Atlantis. No static credentials.
- **Commit signing**: all commits to `main` GPG-signed; tags signed (`git tag -s`); enforced via branch protection.
- **Merge to `main`**: auto-tag semantic version (`vMAJOR.MINOR.PATCH`); changelog from PR titles; SBOM from `tofu providers`.
- **Drift detection**: scheduled `tofu plan`, results posted to a drift channel.

### Provider & State Management

- State: S3 + DynamoDB (AWS), GCS (GCP). Workspaces per environment.
- Root modules declare the backend. Shared modules **never** declare a backend.
- `versions.tf` pins providers to minor version. `required_version` in every module.

### Secrets Handling

- No static credentials. OIDC federation only.
- Secrets from Vault / AWS Secrets Manager / GCP Secret Manager via data sources — never in state.

### Cross-Layer Communication (SSM Only)

Terraservices in the same business unit share outputs via **SSM Parameter Store**, never via
`terraform_remote_state` or hardcoded variables. This decouples layer state files and allows
layers to be applied independently.

**Publishing pattern** — each layer writes its outputs as SSM parameters on apply:
```hcl
# iam/outputs.tf — publishes role ARNs and other outputs
resource "aws_ssm_parameter" "kms_key_arn" {
  name  = "/environments/${var.environment}/platform/kms-key-arn"
  type  = "String"
  value = local.app_kms_key_arn
  key_id = var.kms_key_arn  # encrypt with the key
}

# network/outputs.tf — publishes network coordinates
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/environments/${var.environment}/platform/vpc-id"
  type  = "String"
  value = module.vpc.vpc_id
}
```

**Consuming pattern** — downstream layers read from SSM via data sources:
```hcl
# data/data.tf
data "aws_ssm_parameter" "kms_key_arn" {
  name = "/environments/${var.environment}/platform/kms-key-arn"
}

# data/variables.tf — no need for vpc_id, subnet_ids, etc. as variables
# data/main.tf
  kms_key_arn = data.aws_ssm_parameter.kms_key_arn.value
```

**SSM naming convention:**
```
/environments/<environment>/<business-unit>/<key>
```

Key names are kebab-case (e.g., `vpc-id`, `kms-key-arn`, `ecs-task-exec-role-arn`,
`sagemaker-exec-role-name`, `data-subnet-ids`, `app-subnet-ids`, `default-sg-id`).

| Must | Must not |
|---|---|
| Write every output another layer needs as an SSM parameter | Use `terraform_remote_state` for cross-layer references |
| Use `key_id` (KMS CMK) on every SSM parameter (Pillar 1) | Hardcode ARNs, IDs, or endpoints in variables |
| Group by environment and business unit in the SSM path | Use account-local parameter names for cross-layer values |
| Remove unused SSM parameters when a layer is refactored | Leave orphaned parameters behind |
| Use `type = "StringList"` for list values (comma-separated) | Use `type = "String"` for multi-value outputs |

### Versioning & Composition

- Semantic versioning (`vMAJOR.MINOR.PATCH`). Breaking changes → MAJOR.
- Consumed via `source = "git::...?ref=v1.2.3"`.
- Internal deps use local paths during dev, git tags before release.
- One module, one resource type.

### Complexity Gates

- > 5 resources in `main.tf` → second reviewer required
- > 20 variables → consider splitting
- > 3 providers → strong architectural justification

### Deprecation

- Tag with deprecation notice in release notes; optional `terraform_data` warning.
- Deprecated versions remain 6 months; then the tag may be removed.

---

## Proposed Modules

These modules are planned but not yet built. Each addresses cross-cutting compliance concerns:

| Module | Pillars | Status |
|---|---|---|
| `aws/cloudtrail` | 5, 7, 8 | Proposed |
| `aws/kms-key` | 1 | Proposed |
| `aws/backup-vault` | 6 | Proposed |
| `aws/oidc-identity-provider` | 2 | Proposed |
| `aws/transit-gateway-attachment` | 3 | Proposed |
| `aws/vpc-endpoint` | 3 | Proposed |
| `aws/security-hub` | 5, 9 | Proposed |
| `gcp/audit-logs` | 5, 7, 8 | Proposed |
| `gcp/vpc-service-controls` | 3, 7 | Proposed |

**Note:** The Transit Gateway and shared VPC Endpoints are deployed as terraservices
in `environments/infra-control-plane/network-hub/` rather than root modules — they're one-of-a-kind shared
infrastructure. The `transit-gateway-attachment` and `vpc-endpoint` modules are the
reusable pieces consumed by workload `network/` terraservices.

---

## Skills (Project-Invocable Slash Commands)

These `.claude/skills/` are available as `/` commands in Claude Code. They're symlinked
from a shared skill repository at `~/Developer/agents/terraform-agents/` (run
`make symlink-skills` to set this up). Use them instead of manual workflows — they
encode the 10-pillar compliance process.

| Command | What it does | Status |
|---|---|---|
| `/create-module` | Generate a new module skeleton with all pillar interfaces, tests, examples, README | Built |
| `/review-module` | Run fmt, validate, Checkov, OPA, Infracost + audit checklist on a module | Built |
| `/create-workload` | Scaffold a terraservice layer in an environment (IAM, network, data, compute, AI) | Built |
| `/add-environment` | Bootstrap a new AWS account + business unit directory skeleton | Built |
| `/add-compliance-gates` | Inject standard pillar variable blocks into an existing module | Built |
| `/add-genai-module` | Scaffold a GenAI agentic runtime module (OpenSearch, Bedrock, Guardrail, SageMaker, pgvector) | Built |
| `/ci-pipeline` | Generate CI/CD config files (GitHub Actions, Atlantis, OIDC setup docs) | Built |

---

## CLI Reference (for Claude)

When asked to create a new module, follow this sequence:

1. **Understand the resource.** Read the AWS/GCP provider docs for the primary resource type.
2. **Create the skeleton.** `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `data.tf`, `versions.tf`.
3. **Add the pillar interfaces.** Copy the standard variable blocks for `kms_key_arn`, `network`,
   `high_availability`, `backup`, `observability`, `data_classification`, `data_residency`,
   `cost_controls`, `iam`, `environment`.
4. **Wire controls into the resource.** Every block in `main.tf` uses the pillar variables.
5. **Add Checkov skip annotations** only when a control genuinely doesn't apply (document why).
6. **Write `tofu test` files** — `defaults.tftest.hcl`, `prod.tftest.hcl`, `compliance.tftest.hcl`.
7. **Write the README** — what it creates, each variable, compliance posture, consuming example.
8. **Write OPA rules** (optional but encouraged for module-specific guardrails).
9. **Run `tofu fmt`**, run tests, confirm they pass.
10. **Present the diff** clearly — variables first, then resources, then tests.

### Commands

- **Run units**: `tofu test tests/defaults.tftest.hcl`
- **Run all**: `tofu test tests/`
- **Format + validate**: `tofu fmt -check && tofu validate`
- **Checkov**: `checkov --framework terraform -d .`
- **OPA**: `opa eval --format json --data policies/ --stdin-input plan.json "data.terraform.deny"`
- **Infracost**: `infracost breakdown --path .`
- **Plan with policy**: `tofu plan -out=plan.tfplan && tofu show -json plan.tfplan > plan.json`

---

## Module Audit Checklist

Before any module is released, confirm every applicable control:

- [ ] KMS key passed via variable, no module-created key
- [ ] TLS ≥ 1.2 enforced on all listeners / CDN
- [ ] No `0.0.0.0/0` ingress by default
- [ ] Private subnets by default, public IP disabled
- [ ] Multi-AZ enabled by default if the resource supports it
- [ ] `deletion_protection = true`
- [ ] `retention_days ≥ 30`
- [ ] Logs shipped to a centralized destination
- [ ] At least one default CloudWatch alarm created
- [ ] IAM role scoped to least privilege, permissions boundary support
- [ ] `CostCenter` tag present
- [ ] `environment` variable set and used in validation
- [ ] `data_classification` set with validations
- [ ] Variables use `nullable = false` where the caller must provide a value
- [ ] `tofu test` files for defaults, prod, and compliance failures
- [ ] README with usage example and compliance posture
- [ ] Checkov passes (or each skip documented)
- [ ] Infracost estimate reasonable for the defaults
