# Atlantis Setup Guide — Anestoa Infrastructure

This guide covers setting up **Atlantis** as the GitOps apply engine for the
Anestoa infrastructure monorepo. Atlantis runs plans and applies from PR
comments, enforces approval gates, and provides a complete audit trail.

---

## Prerequisites

| Requirement | Details |
|---|---|
| **GitHub App** | Atlantis authenticates as a GitHub App (recommended) or a personal access token |
| **AWS Account** | Atlantis runs in the management account (or a dedicated CI/CD account) |
| **OIDC Provider** | GitHub OIDC provider set up in the management account |
| **IAM Role** | `atlantis-base-role` with permissions to assume into environment accounts |
| **State Bucket** | S3 bucket + DynamoDB table per environment (bootstrapped via `landing-zone/bootstrap`) |
| **Webhook** | GitHub repo webhook pointing at the Atlantis server |

---

## Step 1: Create a GitHub App

1. Go to **GitHub Settings → Developer settings → GitHub Apps → New GitHub App**
2. Fill in:
   - **GitHub App name**: `anestoa-atlantis`
   - **Homepage URL**: `https://github.com/mochacat/infra-compliance-blueprint`
   - **Webhook URL**: `https://<atlantis-host>/events`
   - **Webhook secret**: Generate a random secret (store in Vault / AWS Secrets Manager)
3. **Repository Permissions** (read & write):
   - Pull requests: **Read & Write**
   - Checks: **Read & Write**
   - Commit statuses: **Read & Write**
   - Contents: **Read**
4. **Subscribe to events**:
   - Pull request review
   - Pull request
   - Push
   - Issue comment
5. Generate a **private key** and store it securely

---

## Step 2: Set Up the Atlantis IAM Role

The Atlantis server needs an IAM role that can assume into each environment
account to execute OpenTofu.

### Management account role

```hcl
# landing-zone/bootstrap/atlantis-role.tf (reference)
resource "aws_iam_role" "atlantis_base" {
  name = "atlantis-base-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::<mgmt-account-id>:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:mochacat/infra-compliance-blueprint:environment:atlantis"
        }
      }
    }]
  })
}

# Attach the Atlantis policy from the IAM policy reference in repos.yaml
resource "aws_iam_role_policy" "atlantis_base_policy" {
  name   = "atlantis-base-policy"
  role   = aws_iam_role.atlantis_base.name
  policy = file("policies/atlantis-base-policy.json")
}
```

### Cross-account roles

Each environment account needs an `atlantis-exec-role` that trusts the
management account's `atlantis-base-role`:

```hcl
# environments/<env>/<bu>/iam/atlantis-exec-role.tf (reference)
resource "aws_iam_role" "atlantis_exec" {
  name = "atlantis-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::<mgmt-account-id>:role/atlantis-base-role"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach the state + resource management policy
resource "aws_iam_role_policy" "atlantis_exec_policy" {
  name   = "atlantis-exec-policy"
  role   = aws_iam_role.atlantis_exec.name
  policy = data.aws_iam_policy_document.atlantis_exec.json
}
```

---

## Step 3: Deploy Atlantis

### Option A: Docker Compose (single instance)

```yaml
# docker-compose.yml (reference — not checked into repo)
version: "3.8"
services:
  atlantis:
    image: ghcr.io/runatlantis/atlantis:v0.28.0
    ports:
      - "4141:4141"
    volumes:
      - ./github-app-key.pem:/keys/github-app-key.pem
    environment:
      ATLANTIS_GH_APP_ID: "123456"
      ATLANTIS_GH_APP_KEY_FILE: /keys/github-app-key.pem
      ATLANTIS_GH_WEBHOOK_SECRET: "${ATLANTIS_WEBHOOK_SECRET}"
      ATLANTIS_REPO_ALLOWLIST: github.com/mochacat/infra-compliance-blueprint
      ATLANTIS_REPO_CONFIG: /config/repos.yaml
      ATLANTIS_ASSUME_ROLE_ARN: arn:aws:iam::<mgmt-account-id>:role/atlantis-base-role
      ATLANTIS_ATLANTIS_URL: https://atlantis.example.com
      ATLANTIS_PORT: "4141"
      ATLANTIS_DEFAULT_TF_VERSION: "1.13.2"
    command: server
```

### Option B: ECS / EKS (production)

Deploy as a container in the `infra-control-plane/shared-tools/compute`
terraservice. Use Fargate or EKS with:
- **Task role**: `atlantis-base-role`
- **ALB** with TLS termination (ACM certificate)
- **Route53** DNS record pointing at the ALB
- **GitHub App webhook** → ALB DNS name

---

## Step 4: Configure OpenTofu Binary

Atlantis uses the `terraform` binary by default. To use OpenTofu:

1. Install `tofu` on the Atlantis container:
   ```dockerfile
   # Dockerfile.atlantis (reference)
   FROM ghcr.io/runatlantis/atlantis:v0.28.0

   # Install OpenTofu
   RUN curl -fsSL https://get.opentofu.org/install-opentofu.sh | sh

   # Replace terraform symlink with tofu
   RUN ln -sf /usr/local/bin/tofu /usr/local/bin/terraform
   ```

2. Or use `--default-tf-version=1.13.2` and configure Atlantis to download
   the tofu binary via the custom binary downloader.

3. Verify: `atlantis server` should show "OpenTofu 1.13.2" in the logs.

---

## Step 5: Set Up the GitHub Webhook

1. Go to **Repo → Settings → Webhooks → Add webhook**
2. **Payload URL**: `https://<atlantis-host>/events`
3. **Content type**: `application/json`
4. **Secret**: The webhook secret from Step 1
5. **Events**:
   - Pull request reviews
   - Pushes
   - Issue comments
   - Pull requests
6. **Active**: ✅

---

## Step 6: Configure State Backend

Each terraservice declares its own backend in `versions.tf`:

```hcl
# environments/production/platform/data/versions.tf
terraform {
  backend "s3" {
    bucket         = "anestoa-tfstate-production-platform"
    key            = "data/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "anestoa-tfstate-lock-production-platform"
    kms_key_id     = "alias/anestoa-tfstate-key"
  }
}
```

The Atlantis role in each account needs access to:
- **S3**: GetObject, PutObject, DeleteObject, ListBucket on `anestoa-tfstate-*`
- **DynamoDB**: GetItem, PutItem, DeleteItem, DescribeTable on `anestoa-tfstate-lock-*`

These are bootstrapped in `landing-zone/bootstrap/`.

---

## Step 7: Install OPA

OPA evaluates custom Rego policies against the plan JSON. Install alongside
Atlantis:

```dockerfile
# Add to the Atlantis Dockerfile
RUN curl -fsSL -o /usr/local/bin/opa \
  https://github.com/open-policy-agent/opa/releases/download/v1.20.2/opa_linux_amd64_static && \
  chmod +x /usr/local/bin/opa
```

The `atlantis.yaml` workflows reference OPA directly in plan steps. If OPA
isn't installed, plan steps that invoke it will fail.

---

## Step 8: Test the Workflow

1. Open a PR changing a terraservice (e.g., `environments/development/platform/network/`)
2. Atlantis comments on the PR with `plan` output
3. Run `atlantis plan` in a PR comment to re-run (if autoplan is off)
4. Review the plan output
5. In **dev**: Atlantis auto-applies after plan
6. In **safe** (preprod, infra): Team member runs `atlantis apply` in a comment
7. In **prod**: Two approvals required, then `atlantis apply`

### PR comment commands

| Command | Effect |
|---|---|
| `atlantis plan` | Run `tofu plan` on the project Atlantis detects |
| `atlantis plan -p <project>` | Run plan on a specific project |
| `atlantis apply` | Apply the approved plan |
| `atlantis apply -p <project>` | Apply a specific project |
| `atlantis unlock` | Release the state lock |
| `atlantis help` | Show all commands |

---

## Security Considerations

| Concern | Mitigation |
|---|---|
| **Plan output contains secrets** | All secrets come from data sources (AWS Secrets Manager, SSM) — never hardcoded |
| **Unapproved applies** | `apply_requirements: [approved, mergeable]` enforced globally; prod requires 2 approvals |
| **State tampering** | S3 + DynamoDB with KMS encryption, SCP denies non-Atlantis state access |
| **SSM parameter tampering** | SCP 10 (ProtectSSMParameters) restricts write/delete to Atlantis role |
| **OIDC credential theft** | `sub` condition scoped to `repo:mochacat/infra-compliance-blueprint:environment:atlantis` |

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `Error: no project found` | `atlantis.yaml` doesn't match the directory structure |
| `Error: stat ... terraform.tfstate: permission denied` | Atlantis role lacks S3/DynamoDB permissions |
| `Error: loading state: AccessDenied` | Cross-account assume-role not configured |
| `OPA violations found — blocking plan` | Rego policy violation — check the plan details in the PR comment |
| `SSM Contract violations found` | A plan tries to delete an SSM parameter that has downstream consumers |
| `Webhook ping failed` | Atlantis server not reachable — check ALB, security group, DNS |

---

## Related Files

| File | Purpose |
|---|---|
| `atlantis.yaml` | Per-project autoplan, workflow, and policy configuration (checked into repo) |
| `docs/repos.yaml` | Server-level config: repo allowlist, OIDC, IAM policy reference (server-local) |
| `policies/ssm-contract.rego` | OPA policy for SSM parameter dependency protection |
| `ssm-contract.yaml` | Cross-layer SSM dependency graph |
| `landing-zone/reference/STATE-STRATEGY.md` | State backend design and bootstrap flow |