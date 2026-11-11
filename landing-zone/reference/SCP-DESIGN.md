# SCP Design

> Service Control Policy architecture for the landing zone.
> These policies enforce compliance guardrails across all accounts in the organization.
> Designed for small to mid-sized companies — organizational controls without ATS.

---

## 1. Design Principles

1. **Deny by default, allow by exception.** Every SCP starts from "deny everything risky"
   and carves out approved actions.
2. **Attach at the highest OU that needs it.** Security controls apply everywhere
   unless there's a specific reason to scope them. Prod-only controls go on the
   Production OUs.
3. **Exempt essential services.** IAM, Organizations, Route53, CloudFront, STS, and
   Support are always exempted from region and network restrictions — otherwise you
   lock yourself out.
4. **Test SCPs before attaching to prod.** SCPs can break things silently. The
   management account is immune, so you can always fix them.
5. **Version control.** Every SCP is a JSON file in `bootstrap/policies/`, reviewed
   and versioned alongside infrastructure code.

---

## 2. SCP Catalog (10 policies)

### SCP 1: DenyRootUserActions

**Target:** Root OU  
**Effect:** Prevents any IAM action by member account root users.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyRootUserActions",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:PrincipalArn": "arn:aws:iam::*:root"
        }
      }
    }
  ]
}
```

---

### SCP 2: RestrictRegions

**Target:** Root OU  
**Effect:** Denies all actions in non-approved AWS regions.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyNonApprovedRegions",
      "Effect": "Deny",
      "NotAction": ["iam:*", "route53:*", "sts:*", "organizations:*",
                    "cloudfront:*", "support:*", "account:*", "billing:*",
                    "budgets:*", "cur:*", "aws-portal:*", "ce:*", "tax:*",
                    "s3:GetBucketLocation", "s3:ListAllMyBuckets"],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"]
        }
      }
    }
  ]
}
```

---

### SCP 3: EnforceEncryptionAtRest

**Target:** Root OU  
**Effect:** Denies creation of unencrypted resources (S3, EBS, RDS, Redshift, EFS).

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Sid": "DenyUnencryptedS3",      "Effect": "Deny", "Action": "s3:PutBucketEncryption",     "Resource": "*", "Condition": {"Null": {"s3:PutBucketEncryption": true}}},
    {"Sid": "DenyUnencryptedEBS",     "Effect": "Deny", "Action": "ec2:CreateVolume",            "Resource": "*", "Condition": {"Null": {"ec2:Encrypted": false}}},
    {"Sid": "DenyUnencryptedRDS",     "Effect": "Deny", "Action": "rds:CreateDBInstance",        "Resource": "*", "Condition": {"Null": {"rds:StorageEncrypted": false}}},
    {"Sid": "DenyUnencryptedRedshift","Effect": "Deny", "Action": "redshift:CreateCluster",      "Resource": "*", "Condition": {"Null": {"redshift:Encrypted": false}}},
    {"Sid": "DenyUnencryptedEFS",     "Effect": "Deny", "Action": "elasticfilesystem:CreateFileSystem", "Resource": "*", "Condition": {"Null": {"elasticfilesystem:Encrypted": false}}}
  ]
}
```

---

### SCP 4: DenyCloudTrailDisable

**Target:** Root OU  
**Effect:** Prevents disabling or modifying the organization CloudTrail.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyCloudTrailDisable",
      "Effect": "Deny",
      "Action": ["cloudtrail:StopLogging", "cloudtrail:DeleteTrail",
                 "cloudtrail:UpdateTrail", "cloudtrail:PutEventSelectors"],
      "Resource": "*",
      "Condition": {"StringEquals": {"aws:ResourceOrgID": "${aws:OrganizationId}"}}
    }
  ]
}
```

---

### SCP 5: ProtectLogArchiveBucket

**Target:** Infra-Control-Plane OU (Log Archive account)  
**Effect:** Prevents modification or deletion of the Log Archive bucket.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Sid": "DenyBucketPolicyChanges",   "Effect": "Deny", "Action": ["s3:PutBucketPolicy", "s3:DeleteBucketPolicy"],                    "Resource": "arn:aws:s3:::*-audit-logs-*"},
    {"Sid": "DenyObjectLockConfiguration","Effect": "Deny", "Action": ["s3:PutBucketObjectLockConfiguration", "s3:PutObjectLegalHold", "s3:PutObjectRetention"], "Resource": "arn:aws:s3:::*-audit-logs-*"},
    {"Sid": "DenyVersioningSuspension",  "Effect": "Deny", "Action": "s3:PutBucketVersioning",                                          "Resource": "arn:aws:s3:::*-audit-logs-*"}
  ]
}
```

---

### SCP 6: DenyPublicAccess

**Target:** Production, Pre-Production, Development OUs  
**Effect:** Prevents creating publicly-exposed resources.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Sid": "DenyPublicIpOnEC2",       "Effect": "Deny", "Action": "ec2:AssociateAddress",         "Resource": "*", "Condition": {"StringEquals": {"ec2:PublicIp": "*"}}},
    {"Sid": "DenyPublicS3",            "Effect": "Deny", "Action": ["s3:PutBucketAcl","s3:PutObjectAcl"], "Resource": "*", "Condition": {"StringEquals": {"s3:x-amz-acl": ["public-read","public-read-write","authenticated-read"]}}},
    {"Sid": "DenyPublicSecurityGroup", "Effect": "Deny", "Action": ["ec2:AuthorizeSecurityGroupIngress","ec2:RevokeSecurityGroupIngress"], "Resource": "*", "Condition": {"StringEquals": {"ec2:cidr": "0.0.0.0/0"}}}
  ]
}
```

---

### SCP 7: EnforceDeletionProtection

**Target:** /Production/* OUs  
**Effect:** Prevents disabling deletion protection on stateful resources in production.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyDisableDeletionProtection",
      "Effect": "Deny",
      "Action": ["rds:ModifyDBInstance", "elasticache:ModifyReplicationGroup", "docdb:ModifyDBInstance"],
      "Resource": "*",
      "Condition": {"Bool": {"rds:DeletionProtection": false, "elasticache:DeletionProtection": false, "docdb:DeletionProtection": false}}
    }
  ]
}
```

---

### SCP 8: DenySnapshotSkip

**Target:** /Production/* OUs  
**Effect:** Prevents `skip_final_snapshot = true` in production.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenySkipFinalSnapshot",
      "Effect": "Deny",
      "Action": ["rds:DeleteDBInstance", "docdb:DeleteDBInstance", "elasticache:DeleteReplicationGroup"],
      "Resource": "*",
      "Condition": {"Bool": {"rds:SkipFinalSnapshot": true, "docdb:SkipFinalSnapshot": true, "elasticache:SkipFinalSnapshot": true}}
    }
  ]
}
```

### SCP 9: EnforceMandatoryTags

**Target:** Organization Root (all accounts)
**Effect:** Requires `Environment`, `CostCenter`, `DataClassification`, and
`ManagedBy` tags on every taggable resource at create time, and on every
`ec2:CreateTags` operation. Closes the gap where someone creates a resource
**outside** the sanctioned modules (e.g. a raw `aws_iam_role` / `aws_s3_bucket`)
that would otherwise carry no attribution tags.

This is the **second layer** of the layered-protection model (see
`ARCHITECTURE.md`): modules enforce tags by default, this SCP enforces them at
the API boundary, and OPA enforces them at plan time for root-module raw
declarations. Supports SOC 2 CC6.1 (access control / attribution) and
HIPAA §164.312(a)(1) (audit / attribution).

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RequireMandatoryTagsOnCreate",
      "Effect": "Deny",
      "Action": ["ec2:CreateVolume", "ec2:RunInstances", "ec2:CreateVpc", "ec2:CreateSubnet", "ec2:CreateSecurityGroup", "rds:CreateDBInstance", "rds:CreateDBCluster", "elasticache:CreateCacheCluster", "elasticache:CreateReplicationGroup", "opensearch:CreateDomain", "sagemaker:CreateDomain", "sagemaker:CreateNotebookInstance", "sagemaker:CreateEndpoint", "lambda:CreateFunction", "sns:CreateTopic", "sqs:CreateQueue", "logs:CreateLogGroup", "dynamodb:CreateTable", "ecs:CreateCluster", "ecs:CreateService", "elasticfilesystem:CreateFileSystem", "redshift:CreateCluster", "bedrock:CreateModelInvocationJob", "kafka:CreateCluster"],
      "Resource": "*",
      "Condition": {
        "ForAnyValue:Null": {
          "aws:RequestTag/Environment": "true",
          "aws:RequestTag/CostCenter": "true",
          "aws:RequestTag/DataClassification": "true",
          "aws:RequestTag/ManagedBy": "true"
        }
      }
    },
    {
      "Sid": "RequireMandatoryTagsOnTagOperation",
      "Effect": "Deny",
      "Action": "ec2:CreateTags",
      "Resource": "*",
      "Condition": {
        "ForAnyValue:Null": {
          "aws:RequestTag/Environment": "true",
          "aws:RequestTag/CostCenter": "true",
          "aws:RequestTag/DataClassification": "true",
          "aws:RequestTag/ManagedBy": "true"
        }
      }
    }
  ]
}
```

---

## 3. SCP Attachment Strategy

```
Organization Root
├── DenyRootUserActions
├── RestrictRegions
├── EnforceEncryptionAtRest
├── DenyCloudTrailDisable
├── EnforceMandatoryTags
├── ProtectSSMParameters
│
├── OU: Infra-Control-Plane
│   ├── (inherits root SCPs)
│   ├── ProtectLogArchiveBucket
│   ├── Account: Management
│   ├── Account: Log Archive
│   ├── Account: Security
│   ├── OU: /Infra-Control-Plane/Network
│   │   └── Account: Network Hub
│   └── Account: Landing Zone (CI/CD)
│
├── OU: Production
│   ├── (inherits root SCPs)
│   ├── DenyPublicAccess
│   ├── EnforceDeletionProtection
│   ├── DenySnapshotSkip
│   │
│   ├── OU: /Production/Platform      ─── Account: production-platform
│   ├── OU: /Production/Research      ─── Account: production-research
│   └── OU: /Production/DataPlatform  ─── Account: production-data-platform
│
├── OU: Pre-Production
│   ├── (inherits root SCPs)
│   ├── DenyPublicAccess
│   ├── OU: /Pre-Production/Platform  ─── Account: preprod-platform
│   └── OU: /Pre-Production/Research  ─── Account: preprod-research
│
├── OU: Development
│   ├── (inherits root SCPs)
│   ├── DenyPublicAccess
│   ├── OU: /Development/Platform     ─── Account: dev-platform
│   └── OU: /Development/Research     ─── Account: dev-research
│
└── OU: Sandbox
    ├── (inherits root SCPs only — no PublicAccess, no Prod SCPs)
    └── Account: sandbox
```

---

### SCP 10: ProtectSSMParameters

**Target:** Organization Root (all accounts)
**Effect:** Only the Atlantis execution role (and an admin break-glass role) can
create, update, or delete SSM parameters under `/environments/*` and
`/infrastructure/*`. Prevents a rogue principal from tampering with the
cross-layer SSM contract that downstream layers depend on.

This is the **defense-in-depth** layer for the SSM-only cross-layer
communication pattern described in `CLAUDE.md`. The module layer enforces
that outputs are published as SSM parameters, the `ssm-contract.yaml`
manifest tracks who consumes them, and this SCP ensures only Atlantis can
modify them.

Supports HIPAA §164.312(c)(1) (integrity — protect against unauthorized
modification of system configuration) and SOC 2 CC6.1 (logical and physical
access controls).

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenySSMParameterWriteByNonAtlantis",
      "Effect": "Deny",
      "Action": [
        "ssm:PutParameter",
        "ssm:DeleteParameter",
        "ssm:DeleteParameters",
        "ssm:LabelParameterVersion"
      ],
      "Resource": [
        "arn:aws:ssm:*:*:parameter/environments/*",
        "arn:aws:ssm:*:*:parameter/infrastructure/*"
      ],
      "Condition": {
        "ArnNotLike": {
          "aws:PrincipalArn": [
            "arn:aws:iam::*:role/atlantis-*",
            "arn:aws:iam::*:role/admin-*"
          ]
        }
      }
    }
  ]
}
```