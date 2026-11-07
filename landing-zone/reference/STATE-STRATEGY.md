# State Management Strategy

> How OpenTofu state is managed across multiple AWS accounts and environments.

---

## 1. State File Layout

State files follow the terraservice path exactly.

```
s3://<client>-terraform-state/
│
├── landing-zone/
│   ├── bootstrap.tfstate              # Management account state
│   └── baseline.tfstate               # Management account state
│
└── environments/
    ├── infrastructure/
    │   └── network-hub/
    │       ├── transit-gateway.tfstate  # Applied to network-hub account
    │       └── endpoints.tfstate        # Applied to network-hub account
    │
    ├── production/
    │   ├── platform/
    │   │   ├── iam.tfstate
    │   │   ├── network.tfstate
    │   │   ├── data.tfstate
    │   │   ├── compute.tfstate
    │   │   └── ai.tfstate
    │   ├── research/...
    │   └── data-platform/...
    │
    ├── preprod/
    │   └── platform/...
    │
    ├── development/
    │   └── (same structure)
    │
    └── sandbox/
        └── platform/...
```

### Backend Configuration

Each terraservice declares its backend:

```hcl
# environments/production/platform/network/backend.conf
key = "environments/production/platform/network.tfstate"
```

---

## 2. Where the State Bucket Lives

**Recommended:** State bucket in the Management account. Single S3 bucket with
prefix-scoped access per account role.

---

## 3. Terraservice Dependency Graph

```
                ┌──────────────────────┐
                │ landing-zone/        │
                │ bootstrap/           │
                └──────────┬───────────┘
                           ▼
                ┌──────────────────────┐
                │ landing-zone/        │
                │ baseline/            │
                └──────────┬───────────┘
                           ▼
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
   ┌────────────┐   ┌────────────┐   ┌────────────┐
   │infra/      │   │production/ │   │development/│
   │network-hub/│   │platform/   │   │platform/   │
   │transit-    │   │iam/        │   │iam/        │
   │gateway/    │   └─────┬──────┘   └─────┬──────┘
   └─────┬──────┘         │                 │
         │              ┌──▼──────┐    ┌────▼──────┐
         │              │network/ │    │ network/  │
         │              │(TGWA)   │    │ (TGWA)    │
         │              └──┬──────┘    └────┬──────┘
         │                 │                │
         │              ┌──▼──────┐    ┌────▼──────┐
         │              │ data/   │    │  data/    │
         │              └──┬──────┘    └────┬──────┘
         │              ┌──┼───┐       ┌────┼──────┐
         │              │  │   │       │    │      │
         │              ▼  ▼   ▼       ▼    ▼      ▼
         │          ┌──┐ ┌──┐        ┌──┐ ┌──┐
         │          │co│ │ai│        │co│ │ai│
         │          └──┘ └──┘        └──┘ └──┘
         ▼
   ┌────────────┐
   │endpoints/  │
   └────────────┘
```

---

## 4. Bootstrap Problem

1. Convert existing account to Management account (`aws organizations create-organization`)
2. Bootstrap: create OUs, SCPs, member accounts
3. Baseline: deploy CloudTrail, GuardDuty, cross-account roles
4. Network Hub: deploy Transit Gateway + shared endpoints
5. Environments: deploy terraservices per environment per business unit

---

## 5. State Access Control

Each account's `opentofu-deploy` role only has access to its own prefix:

```json
{
  "Sid": "AllowWorkloadAccess",
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::<account-id>:role/opentofu-deploy"},
  "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
  "Resource": [
    "arn:aws:s3:::<bucket>",
    "arn:aws:s3:::<bucket>/environments/<env>/<business-unit>/*"
  ]
}
```