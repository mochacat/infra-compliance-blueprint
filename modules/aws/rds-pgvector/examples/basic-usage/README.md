# rds-pgvector — basic usage

Creates an Aurora PostgreSQL cluster with `pgvector` and an RDS Proxy for a
RAG workload's hybrid vector + relational store. Sources DB credentials from
Secrets Manager (never a committed password).

## Usage

```bash
cd examples/basic-usage
tofu init
tofu plan
```