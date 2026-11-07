# basic-usage

Minimal, compliant example: a customer-managed KMS key with rotation on,
least-privilege policy, and the data-classification/residency gates in place.

## What it demonstrates

- Encryption — a CMK that consuming modules feed into their
  `kms_key_arn` input.
- Access Control & Least Privilege — key usage and admin grants are explicit ARNs,
  never `"*"`.
- Data Residency & Sovereignty — the key is tagged with its data classification and
  jurisdiction; a `phi` classification forces `sovereign_only = true` and
  forbids `multi_region`.

## Run it

```bash
cd modules/aws/kms-key/examples/basic-usage
tofu init
tofu apply -var account_id=123456789012 \
           -var app_role_arn=arn:aws:iam::123456789012:role/app \
           -var kms_admin_arn=arn:aws:iam::123456789012:role/admin
```

The URL base is intentionally generic (`git::...`) so it can be pointed at
your own registry or a VCS tag before release.