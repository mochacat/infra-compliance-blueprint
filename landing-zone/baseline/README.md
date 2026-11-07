# Baseline Terraservice

**Change frequency:** Monthly.  
**State location:** Management account.  
**Runs from:** Management account.  
**Depends on:** Bootstrap terraservice (the accounts and OUs it created).

> **Existing org?** The baseline adapts cleanly to an account that *already*
> belongs to an organization, unlike the bootstrap (which is greenfield-only —
> see the bootstrap README). A team with an existing management account should
> run this terraservice as its first adoption step: importing what it already
> has (informal CloudTrail, existing GuardDuty) and letting the plan surface the
> drift — the missing audit bucket, KMS, Object Lock, and security findings
> wiring. Just set `org` feature references to your existing org.

## What this is

The **security + compliance runtime** that governs every account in the
organization. Where the bootstrap answers *"what must no account ever be able to
do?"* (via SCPs), the baseline answers *"what must every account always record,
monitor, and prove?"* (via CloudTrail, Config, GuardDuty, Security Hub, and the
immutable audit trail).

> **Policy vs. evidence.** SCPs are the *preventive* layer — they stop a
> non-compliant resource from existing. The baseline is the *detective and
> evidential* layer — it records everything that does happen, so HIPAA
> 164.312(b) and SOC 2 CC7.1 audits have an unalterable record to point at.
> A compliant environment needs both.

The baseline is **deployed once at the org level from the management account**
and applies to all current and future accounts:

- **CloudTrail** — every API call in every account, in one immutable trail.
- **AWS Config** — every resource's config + compliance state, snapshotted centrally.
- **GuardDuty** — threat detection, findings consolidated in the Security account.
- **Security Hub** — a single pane of glass for all security + compliance findings.
- **Audit bucket** — the immutable evidence store (Object Lock, versioning, KMS).
- **`opentofu-deploy` role** — least-privilege CI/CD role (added per account).

---

## What it creates

| Resource | Where | Purpose | Backed by control |
|---|---|---|---|
| `aws_s3_bucket` `audit` | Log Archive | Immutable evidence sink for all logs | HIPAA 164.312(b), SOC 2 CC7.1 |
| `aws_kms_key` `audit` | Log Archive | CMK encrypting the audit bucket | HIPAA 164.312(a)(2)(iv) |
| `aws_cloudtrail` `org` | Management | Multi-region org trail → audit bucket | HIPAA 164.312(b) |
| `aws_cloudwatch_log_group` | Management | CloudTrail → CloudWatch for alerting | SOC 2 CC7.1 |
| `aws_config_configuration_recorder` | Management | Records resource + compliance state | SOC 2 CC7.1 |
| `aws_config_delivery_channel` | Management | Config snapshots → audit bucket | SOC 2 CC7.1 |
| `aws_guardduty_detector` | Security | Org-wide threat detection | SOC 2 CC7.2 |
| `aws_guardduty_organization_configuration` | Security | Auto-enables new accounts | SOC 2 CC7.2 |
| `aws_securityhub_account` | Security | Central findings hub | SOC 2 CC7.4 |
| `module.deploy_role` | Management | Least-privilege CI/CD role | SOC 2 CC6.1 |

---

## How the security model is layered

```
       ┌─────────────────────────────────────────────────────────┐
       │  SCPs (bootstrap) — PREVENT: unencrypted, public,       │
       │  non-region-approved, root, disable-CIS resources       │
       └─────────────────────────────────────────────────────────┘
                                ▼
       ┌─────────────────────────────────────────────────────────┐
       │  Baseline — RECORD & MONITOR everything that does run:  │
       │  ─ CloudTrail  → every API call (multi-region, immut.)  │
       │  ─ AWS Config  → every resource + compliance snapshot   │
       │  ─ GuardDuty   → threat detection, findings to Security │
       │  ─ SecurityHub → aggregated compliance + security pane  │
       │  ─ Audit bucket→ tamper-evident evidence, 7-yr lock     │
       └─────────────────────────────────────────────────────────┘
                                ▼
       ┌─────────────────────────────────────────────────────────┐
       │  Workload modules — build compliant resources that the  │
       │  SCPs allow and the baseline observes.                  │
       └─────────────────────────────────────────────────────────┘
```

---

## The audit bucket (why it is tamper-evident)

Audit integrity is a **hard control**, not best-effort. This bucket is
configured so the evidence cannot be altered retroactively — even by an account
root:

| Control | Setting | What it defeats |
|---|---|---|
| **Object Lock — COMPLIANCE mode** | `default_retention.mode = COMPLIANCE`, `days = 2557` | Root user deleting/overwriting logs via the console or CLI |
| **Versioning** | `Enabled` | Any overwrite becomes a new version; prior versions survive |
| **KMS encryption** | `sse_algorithm = aws:kms`, CMK | Data at rest unreadable without the dedicated audit key |
| **SecureTransport deny** | bucket policy `aws:SecureTransport = false` → deny | Plaintext (non-TLS) exfiltration |
| **Public access block** | all four flags, plus `deny-public-access` **SCP** | Exposure (belt and suspenders) |
| **`prevent_destroy`** | tofu lifecycle | Accidental `tofu destroy` of the whole bucket |

> **Compliance mode ≠ governance mode.** COMPLIANCE means *no one*, including the
> AWS account owner, can delete an object before the retention period expires.
> This is the property HIPAA's record-integrity control requires. GOVERNANCE
> allows privileged users to bypass with a grant — useful for operational fixes
> but **not** acceptable as the default for an audit store in a regulated env.

---

## Variables & defaults

| Variable | Default | Notes |
|---|---|---|
| `region` | `us-east-1` | Must be an approved region |
| `environment` | `prod` | dev/test/staging/prod/commercial |
| `management_account_id` | *(required)* | Account tofu runs from |
| `log_archive_account_id` | `null` | Set to create the immutable audit bucket + CloudTrail sink |
| `security_account_id` | `null` | Set to delegate GuardDuty + Security Hub |
| `audit_log_bucket` | `anestoa-audit-logs` | Bucket name |
| `log_retention_days` | `2557` | Min 2557 (7 years) |
| `audit_lock_mode` | `COMPLIANCE` | COMPLIANCE or GOVERNANCE |
| `cloudtrail_org` | `true` | Org-wide CloudTrail |
| `cloudwatch_log_retention` | `90` | Min 30 |
| `guardduty_delegate` | `true` | Delegate GuardDuty admin to Security account |
| `securityhub_delegate` | `true` | Delegate Security Hub admin to Security account |
| `config_org` | `true` | Org-wide AWS Config |
| `cicd_role_name` | `opentofu-deploy` | CI/CD role name |
| `cicd_oidc_provider_arn` | `null` | OIDC provider for the CI/CD trust |
| `default_tags` | *(compliance tags)* | ManagedBy, Purpose, DataClassification, CostCenter |

### Gated by account IDs

Two variables control how much of the baseline is live:

- **`log_archive_account_id = null`** (default) → audit bucket, org CloudTrail,
  and Config are **skipped** (their `count` is 0). Set it once the Log Archive
  account exists.
- **`security_account_id = null`** (default) → GuardDuty + Security Hub
  delegation is **skipped**. Set it once the Security account exists.

This lets a single-account setup start with the management-account baseline and
expand as member accounts are added.

---

## Usage

```bash
cd landing-zone/baseline
tofu init

tofu plan \
  -var management_account_id=123456789012 \
  -var log_archive_account_id=123456789012 \
  -var security_account_id=123456789012
tofu apply
```

> If you are running single-account (no separate Log Archive / Security
> accounts yet), pass all account IDs the same value and the baseline will
> create the audit bucket and detectors in that one account.

---

## Relationship to the bootstrap

| Layer | Question it answers | Runs when |
|---|---|---|
| **Bootstrap** | What must no one ever be able to do? (SCPs, OUs) | Org creation |
| **Baseline** | What must every account record + monitor? | After bootstrap, then monthly |
| **Workload envs** | What compliant resources do we actually run? | Continuously |

---

## Compliance mapping

| Control | HIPAA | SOC 2 | Baseline component |
|---|---|---|---|
| Immutable audit trail | 164.312(b) | CC7.1 | CloudTrail + audit bucket |
| Encryption at rest | 164.312(a)(2)(iv) | CC6.6 | KMS audit key |
| Offsite / retained records | 164.308(a)(7) | — | 7-year Object Lock |
| Continuous monitoring | 164.308(a)(5)(ii)(C) | CC7.2 | GuardDuty |
| Security event escalation | 164.312(d) | CC7.4 | Security Hub delegation |
| Resource change detection | — | CC7.1 | AWS Config |
| Least-privilege automation | 164.312(a)(1) | CC6.1 | `opentofu-deploy` role |

---

## Testing

```bash
cd landing-zone/baseline
tofu fmt -check
tofu validate
tofu test tests/
```