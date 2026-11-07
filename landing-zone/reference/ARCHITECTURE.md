## 9. Compliance: HIPAA & SOC 2 Type II

The landing zone is designed as a **compliant-by-default foundation** for regulated
environments. Every control below is enforced at the organizational level — environment
accounts inherit them and cannot opt out.

### HIPAA Controls

| HIPAA Rule | Landing Zone Control | Where |
|---|---|---|
| **164.312(a)(1)** — Access control | SCPs enforce IAM permissions boundaries on all roles; root user actions denied in member accounts | Bootstrap SCPs |
| **164.312(a)(2)(iv)** — Encryption at rest | SCP denies creation of unencrypted resources (S3, EBS, RDS, EFS). KMS key required for every stateful resource. | Bootstrap SCPs + modules |
| **164.312(e)(1)** — Encryption in transit | SCP denies TLS < 1.2 on load balancers, CloudFront, API Gateway. VPC endpoints enforce private connectivity. | Bootstrap SCPs |
| **164.312(b)** — Audit controls | Organization CloudTrail (multi-region, management + data events) → Log Archive with Object Lock COMPLIANCE mode. AWS Config records resource state changes. | Baseline |
| **164.308(a)(1)(ii)(D)** — Information access management | Cross-account roles scoped to least privilege. No shared service roles. Every role has a permissions boundary. | Baseline + modules |
| **164.308(a)(5)(ii)(C)** — Security incident response | GuardDuty + Security Hub in Security account. Findings route to `security_findings_topic_arn`. Automated alerting. | Baseline |
| **164.310(a)(2)(iv)** — Facility access / workstation security | VPCs default to private-only. No public IPs. No `0.0.0.0/0` ingress. Hub-and-spoke keeps traffic internal. | Baseline + SCPs + Network Hub |
| **164.312(c)(2)** — Integrity controls | S3 Object Lock COMPLIANCE mode prevents log modification/deletion. Versioning enabled on all audit buckets. | Baseline |
| **164.308(a)(8)** — Business Associate Agreements | Prerequisite: AWS BAA must be in place before any PHI enters the environment. Documented as a gating step. | Process (not code) |

### SOC 2 Type II Controls

| SOC 2 Category | Landing Zone Control | Where |
|---|---|---|
| **CC6.1** — Logical and physical access | IAM roles with permissions boundaries, SCPs enforce least privilege, root user actions denied | Bootstrap SCPs |
| **CC6.6** — Encryption | KMS required for all data at rest. TLS >= 1.2 for all in-transit communication. | Bootstrap SCPs + modules |
| **CC6.7** — Transmission security | VPC endpoints, private subnets, no public exposure by default, hub-and-spoke keeps traffic within AWS network | Baseline + SCPs + Network Hub |
| **CC7.1** — Monitoring | CloudTrail, GuardDuty, Security Hub, AWS Config. Centralized in Security and Log Archive accounts. | Baseline |
| **CC7.2** — Incident response | Security findings -> SNS topic -> SIEM. Automated GuardDuty threat detection. | Baseline |
| **CC7.3** — Change management | Atlantis with OPA evaluation. All changes flow through PRs. No direct applies. | Landing Zone account |
| **CC7.4** — Security event escalation | GuardDuty delegated admin in Security account. Findings visible cross-account. | Baseline |
| **CC9.1** — Risk mitigation | SCPs enforce region restriction, encryption, no public access. Proactive controls prevent non-compliant resources. | Bootstrap SCPs |

### Shared Controls

| Control | Landing Zone Mechanism | Compliance Mapping |
|---|---|---|
| **Least privilege** | Permissions boundary on every IAM role. SCPs deny broad actions. | HIPAA 164.312(a)(1), SOC 2 CC6.1 |
| **Immutable audit logs** | Object Lock COMPLIANCE, versioning, no bucket policy modifications | HIPAA 164.312(b), SOC 2 CC7.1 |
| **Data classification** | `data_classification` variable on every stateful module. SCPs enforce sovereign-only for PHI. | HIPAA 164.312(a)(1) |
| **Deletion protection** | `deletion_protection = true` default on all stateful resources. SCP denies deletion of CloudTrail and Log Archive. Prod SCPs enforce this in production. | HIPAA 164.312(c)(2), SOC 2 CC6.1 |
| **Region restriction** | SCP denies non-approved regions. Approved regions must have BAA in place. | HIPAA 164.314(a)(1) |
| **Separation of duties** | Different accounts for management, security, logging, networking, and workloads. No single account has all permissions. | SOC 2 CC6.1, CC6.2 |

### Prerequisites for HIPAA

Before any PHI can be stored in this environment, the following must be in place:

1. **AWS BAA signed** — AWS will only sign a BAA for accounts in an organization
   with all features enabled. The bootstrap terraservice enables this.
2. **Approved regions** — Only AWS regions where AWS has signed a BAA with the
   client. Updated in the `RestrictRegions` SCP.
3. **Security account delegated admin** — GuardDuty and Security Hub must be
   delegated to the Security account before PHI workloads are deployed. Baseline
   handles this.
4. **Log Archive retention** — Object Lock retention must meet the client's
   document retention policy (typically 6+ years for HIPAA). Configured in
   baseline variables.

### What the landing zone does NOT cover

The landing zone provides the organizational guardrails. Workload-specific
HIPAA/SOC 2 controls must be implemented in the environment terraservices:

- Application-level PHI encryption (field-level, column-level)
- Database audit logging (RDS Enhanced Monitoring, Aurora Advanced Auditing)
- BA agreements with third-party SaaS providers used by the workload
- Application access control (IAM identity federation, Okta, etc.)
- Data backup and DR testing procedures
- Incident response runbooks
- Model-level guardrails (handled by the `bedrock-guardrail` module)