# Bootstrap Terraservice

**Change frequency:** Quarterly / yearly.
**State location:** Management account.
**Runs from:** Management account.
**Depends on:** Nothing.

## Greenfield only — skip this if you already have an organization

This terraservice **creates the AWS Organization, OU structure, and SCPs from
scratch**. It is intended **only for greenfield setups** — an org that does not
yet exist.

**If your account is already part of an organization** (the common case for an
early-stage team that has been operating on a single management account), **do
not run `tofu apply` on this terraservice** — it will fight your existing org,
attempt to re-create OUs, and re-attach SCPs on top of what is already there.

Instead, **skip it or adopt/inspire from it**:

- **Adopt** — use the OU layout, SCP list, and `policies/*.json` here as the
  target posture. Inspect your existing org and apply any *missing* SCPs and
  OUs selectively, by hand or with a small wrapper, rather than re-running the
  whole terraservice.
- **Skip** — if your org is already shaped close enough, just take the
  `baseline/` terraservice (audit logging, GuardDuty, Config, audit bucket),
  which adapts cleanly to an existing management account.

A greenfield team (new AWS org, no existing structure) ignores this note and
runs the terraservice normally.

## Purpose

Creates the AWS Organization, OU structure, and SCPs that form the compliance
foundation of the landing zone. Run once when establishing a new org.

> **Scope note:** This is a management-account-only terraservice. It is NOT a
> reusable module — it exists to establish the org once, not to be called from
> multiple environments. Every resource here is create-once and `prevent_destroy`.

## What It Creates

### Organization

- `aws_organizations_organization` with `feature_set = "ALL"` — enables SCPs,
  consolidated billing, and cross-account join of all AWS services.
- Service access principals for CloudTrail, Config, GuardDuty, Security Hub,
  SSO, and S3.

### OU Structure

```
Root
├── Infra-Control-Plane
│   └── Network
├── Production
│   ├── Platform
│   ├── Research
│   └── DataPlatform
├── Pre-Production
│   ├── Platform
│   └── Research
├── Development
│   ├── Platform
│   └── Research
└── Sandbox
```

The OU path maps directly to the `environments/` directory layout:

| Directory | OU Path |
|---|---|
| `environments/production/platform/` | `/Production/Platform` |
| `environments/production/research/` | `/Production/Research` |
| `environments/infra-control-plane/network-hub/` | `/Infra-Control-Plane/Network` |

### Service Control Policies

Eight SCPs, defined as JSON in `policies/`:

| SCP | Attached To | What it blocks |
|---|---|---|
| `DenyRootUserActions` | Root | Any action by member-account root users |
| `RestrictRegions` | Root | Any resource action outside approved regions |
| `EnforceEncryptionAtRest` | Root | Creating unencrypted S3, EBS, RDS, Redshift, EFS |
| `DenyCloudTrailDisable` | Root | Stopping or modifying the org CloudTrail |
| `DenyPublicAccess` | Production, Pre-Prod, Development | Public S3 ACLs, public SG ingress, public IPs |
| `EnforceDeletionProtection` | Production | Disabling deletion protection on RDS/ElastiCache |
| `DenySnapshotSkip` | Production | `skip_final_snapshot = true` on delete |
| `ProtectLogArchiveBucket` | Infra-Control-Plane | Modifying the audit log bucket |

Policy hierarchy follows the defense-in-depth principle: root-level SCPs apply
everywhere; environment-specific SCPs layer on top.

### Member Accounts

`accounts.tf` contains commented-out `aws_organizations_account` resources for
all 9 member accounts. These are commented out because:

1. Each account requires a **real, unique email address** to receive the invite.
2. Creating an account takes ~2 minutes and cannot be undone without closing it.

To enable them:
1. Set up email aliases (`aws-security@yourdomain.com`, etc.)
2. Uncomment the account resources
3. `tofu apply`

The management account (the one you run tofu from) is not created here — it
already exists and is the org root.

### IAM Identity Center (optional)

If `sso_instance_arn` is set, creates an `Admin` permission set with
`AdministratorAccess`. Intended as a starting point — replace with
least-privilege permission sets in production.

## Usage

```hcl
# terraform.tfvars
region                 = "us-east-1"
org_name               = "Anestoa"
org_email              = "aws-root@anestoa.io"
account_email_domain   = "anestoa.io"
allowed_regions        = ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"]
audit_log_bucket_name  = "anestoa-audit-logs"
```

```bash
cd landing-zone/bootstrap
tofu init
tofu plan
tofu apply
```

### Prerequisites

- AWS credentials with `organizations:CreateOrganization` in the target account.
- The account must **not already belong to an organization**.
- Root access to the management account (required to enable `ALL` features).

## What to do after apply

1. **Create member accounts** — uncomment `accounts.tf` and apply once email
   aliases exist.
2. **Deploy the baseline** — CloudTrail, Config, GuardDuty, Security Hub
   (`landing-zone/baseline/`).
3. **Deploy shared network** — Transit Gateway in the network-hub account
   (`environments/infra-control-plane/network-hub/`).
4. **Deploy workload environments** — `environments/<env>/<business-unit>/`.

## Testing

```bash
cd landing-zone/bootstrap
tofu fmt -check
tofu validate
tofu test tests/
```

The test suite uses `command = plan` and does not require AWS credentials — it
validates variable constraints and resource configuration.

## Compliance Mapping

| Control | HIPAA | SOC 2 | Where |
|---|---|---|---|
| Root user denied everywhere | 164.312(a)(1) | CC6.1 | `DenyRootUserActions` |
| Region restriction | 164.314(a)(1) | CC9.1 | `RestrictRegions` |
| Encryption enforced | 164.312(a)(2)(iv) | CC6.6 | `EnforceEncryptionAtRest` |
| Audit trail immutable | 164.312(b) | CC7.1 | `DenyCloudTrailDisable` |
| Network isolation | 164.310(a)(2)(iv) | CC6.7 | `DenyPublicAccess` |
| Data integrity | 164.312(c)(2) | — | `EnforceDeletionProtection`, `DenySnapshotSkip`, `ProtectLogArchiveBucket` |