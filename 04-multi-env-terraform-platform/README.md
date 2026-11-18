# Multi-Environment Cloud Infrastructure Platform (Terraform + AWS)

Reusable modules deployed to **dev / staging / prod** with isolated state, isolated IAM, policy-as-code gates, approval-gated applies and **keyless** GitHub Actions auth (OIDC).

## Architecture
```
bootstrap/  -> S3 state bucket (versioned, encrypted) + DynamoDB lock + GitHub OIDC provider + 1 IAM role per env
modules/network   -> VPC, public/private subnets, optional NAT (cost toggle)
modules/workload  -> encrypted S3 bucket, EC2 (IMDSv2, SSM, no inbound), least-priv instance role
envs/{dev,staging,prod} -> thin roots: own backend key, own tfvars
.github/workflows -> plan (PR) | apply (main, dev→staging→prod) | destroy (manual)
```

## Requirement mapping
| Requirement | Implementation |
|---|---|
| Reusable modules | `modules/network`, `modules/workload` consumed by all envs |
| Isolated state | one state key per env (`dev/…`, `staging/…`, `prod/…`) in a versioned S3 bucket |
| Remote state + locking | S3 backend + DynamoDB table `mep-tflock` |
| Isolated permissions | per-env IAM role; its state policy only allows `<env>/*` keys; trust bound to GitHub Environment |
| Policy checks | Checkov in PR workflow (fails build); `make scan` supports tfsec |
| Plan approvals | PR plan artifacts + GitHub Environment *required reviewers* on `staging` and `prod` |
| Keyless CI auth | `aws-actions/configure-aws-credentials` with OIDC – no AWS secrets in GitHub |
| Teardown & cost | see below |

## Setup
1. `cd bootstrap && terraform init && terraform apply -var github_repo=<owner>/<repo>`
2. In GitHub → Settings → Variables: `TF_STATE_BUCKET` (output `state_bucket`), `AWS_ROLE_ARN_PREFIX` = `arn:aws:iam::<acct>:role/mep-ci`
3. GitHub → Environments: create `dev`, `staging`, `prod`; add *Required reviewers* to `staging` and `prod`.
4. Open a PR → plan + Checkov run. Merge → dev applies, then waits for approval for staging and prod.

## Teardown
- Per env: Actions → **terraform-destroy** (dev/staging only; prod is intentionally not offered) or `make destroy ENV=dev`.
- Full cleanup: destroy envs, then `cd bootstrap && terraform destroy` (state bucket has `prevent_destroy`; remove the lifecycle block deliberately).

## Cost controls
- NAT gateway (largest idle cost) only in prod (`enable_nat`).
- Small instance types in non-prod; `instance_count = 1` in dev/staging.
- Destroy dev/staging when idle (manual workflow). Add AWS Budgets / Cost Anomaly Detection alerts (recommended).
- `default_tags` (Environment, Project) enable cost allocation reports.

## Accepted Checkov skips
See `.checkov.yaml` – each skip is a cost/complexity trade-off for a demo; enable KMS CMKs, flow logs and replication for real production.
