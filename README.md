# ☁️ Infrastructure as Code with Terragrunt & OpenTofu

![CI](https://github.com/thiagoanegreiros/terragrunt-sample/actions/workflows/ci.yml/badge.svg)
![OpenTofu](https://img.shields.io/badge/OpenTofu-1.9+-blueviolet)
![Terragrunt](https://img.shields.io/badge/Terragrunt-0.56+-blue)
![Checkov](https://img.shields.io/badge/Checkov-passed-brightgreen)
![TFLint](https://img.shields.io/badge/TFLint-configured-informational)
![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen.svg)

This is an **Infrastructure-as-Code (IaC)** project using **Terragrunt** over **OpenTofu**, designed to deploy a modular and versioned AWS infrastructure with CI/CD validation.

The structure is separated by environments (`dev`, `prod`) and includes automated security/static checks using `Checkov`, `TFLint`, and `pre-commit`.
---

## 🌍 Structure Overview

```shell
├── common-resources/
│   └── website/              # Reusable module for S3 + CloudFront + WAF
├── envs/
│   ├── dev/
│   │   └── front/            # Terragrunt stack for dev frontend
│   └── prod/
│       └── front/            # Terragrunt stack for prod frontend
├── project.hcl               # Shared project-level variables
├── .tflint.hcl               # Linting configuration
├── .pre-commit-config.yaml   # Pre-commit hooks
├── root.hcl   # main reusable hcl file
```

## ⚙️ Features

- ✅ Terragrunt with environment inheritance  
- ✅ Modular OpenTofu using local structure  
- ✅ S3 + CloudFront + WAF + ACM  
- ✅ Optional origin failover for CloudFront  
- ✅ GitHub Actions-ready  
- ✅ Checkov + TFLint integration  
- ✅ Pre-commit with security/static checks  
- ✅ Secure usage of Workload Identity or Profiles  
- ✅ Terratest or terraform-compliance for automated testing  
- 🛡️ OIDC federation for GitHub Actions  

---

## 🚀 Usage

### 📦 Initialize a stack

```bash
cd envs/dev/front
terragrunt init
terragrunt apply

Terragrunt dynamically generates backend.tf and provider.tf.
```

## 🛡️ Guardrails & Quality Harness

This project enforces a multi-layer quality harness that catches issues at every stage — from local edits to CI runs and live plan/apply operations.

### Overview

| Layer | Tool | When It Runs | What It Checks | On Failure |
|-------|------|-------------|----------------|------------|
| Format | `tofu fmt` / `hclfmt` | Every commit | HCL & Terraform formatting | Block commit |
| Lint | TFLint | Commit, push, CI, before plan | AWS rule violations, best practices | Block |
| Security | Checkov | Push, CI, before plan/apply | Security misconfigurations | Block |
| Policy | Conftest / OPA | Push, after file edit | Tags, S3 security, variable contract, module complexity, Terragrunt contracts | Warn / Deny |
| Policy coverage | `run-opa-coverage.sh` | Every commit | Critical S3 types have explicit OPA coverage | Block commit |
| Unit tests | `tofu test` | Push, CI | Module resource assertions | Block |
| Cost gate | Infracost | Before plan/apply, CI | Monthly cost vs threshold | Block plan |
| AI guard | `hook-guard-apply.sh` | VS Code / Claude Code | Prevents agent from running `apply` | Block |
| Auto-lint | `hook-lint-tf.sh` | After `.tf` edit (VS Code) | Runs TFLint on saved file | Warning |
| Auto-validate | `hook-validate-tf.sh` | After `.tf` edit (VS Code) | Runs `tofu validate` on module | Warning |
| Auto-test policy | `hook-test-rego.sh` | After `.rego` edit (VS Code) | Re-runs Conftest for edited policy | Warning |
| CI pipeline | GitHub Actions | Push to master / PRs | fmt → validate → lint → plan → cost | Block merge |

---

### Pre-commit Pipeline (`.pre-commit-config.yaml`)

Two-stage pipeline using [pre-commit](https://pre-commit.com/). Install with:

```bash
pre-commit install --hook-type pre-commit --hook-type pre-push
```

**Stage 1 — pre-commit** (runs on every `git commit`, fast):

- `tofu fmt` — recursive format check on `common-resources/`
- `hclfmt_check` — HCL formatter check on Terragrunt files
- `opa_coverage` — verifies that critical resource types (e.g. `aws_s3_bucket_acl`) have explicit OPA policy coverage

**Stage 2 — pre-push** (runs before `git push`, slower):

- `terraform_tflint` — AWS-specific lint rules
- `terraform_checkov` — security/best-practice scanning
- `terraform_conftest` — OPA policy enforcement on `.tf` files
- `conftest_terragrunt` — OPA policy enforcement on `.hcl` files
- `tofu_tests` — runs all `*.tftest.hcl` unit tests
- `tofu_validate` — syntax and schema validation

---

### OPA / Conftest Policies (`policies/`)

Custom policies enforced via [Conftest](https://www.conftest.dev/) on both Terraform and Terragrunt files.

**Terraform policies (`policies/terraform/`):**

- **`required_tags.rego`** — every AWS resource must declare the tags `Environment`, `Project`, and `ManagedBy`. The `ManagedBy` tag must equal `"opentofu"`. A curated list of 52 sub-resource types (IAM policies, S3 sub-resources, WAF logging configs, etc.) are exempted.

- **`no_public_acl.rego`** — S3 buckets must not use public ACLs (`public-read`, `public-read-write`, `authenticated-read`). The `aws_s3_bucket_public_access_block` resource must set `block_public_acls = true` and `block_public_policy = true`.

- **`variable_contract.rego`** — every variable in a module must have a non-empty `description` and an explicit `type`. Enforces self-documenting module interfaces.

- **`module_score.rego`** — weighted complexity scorer that assigns points per resource, variable, dynamic block, `depends_on`, module call, data source, etc. Thresholds: **warn** at score ≥ 25, **deny** at score > 40. Penalizes mixing `count` + `for_each` with a fixed 4-point penalty.

**Terragrunt policies (`policies/terragrunt/`):**

- **`no_hardcoded_ids.rego`** — blocks hardcoded Cognito pool IDs, ARNs, and Cognito hosted-UI domains inside `generate` blocks. Recommends SSM Parameter Store as the alternative.

- **`generate_block_contract.rego`** — all `generate` block paths must end in `.tf` and use `if_exists = "overwrite_terragrunt"`.

---

### Terraform Unit Tests (`common-resources/website/tests/test.tftest.hcl`)

Mock-provider unit tests run with `tofu test`. They assert:

- **S3** — naming convention, versioning enabled, KMS encryption (`aws:kms`), all four public-access block flags set to `true`, lifecycle rules (7-day abort on incomplete multipart uploads, 90-day expiration on log/backup buckets)
- **CloudFront** — distribution enabled, origin failover group with primary + secondary S3 origins, geo-restriction includes Brazil (`BR`), minimum TLS version `TLSv1.2_2021`
- **WAF** — DDoS rule group and Web ACL both scoped to `CLOUDFRONT`
- **Kinesis Firehose** — `extended_s3` destination, KMS encryption, public-access block enabled, 90-day expiration lifecycle
- **Tags** — `ManagedBy = "opentofu"`, `Environment` matches `var.env`

Run manually:

```bash
.vscode/run-tofu-test.sh
```

---

### Root Terragrunt Before-Hooks (`root.hcl`)

Three hooks execute automatically before every `terragrunt plan` and `terragrunt apply`:

1. **`validate_tf_files`** — runs TFLint with error-level severity on the stack's module directory.
2. **`checkov_tf_files`** — runs Checkov with the project's whitelist of exempted rules (see `.checkov.yaml`).
3. **`infracost_gate`** — generates a plan, runs `infracost breakdown`, and blocks execution if the estimated monthly cost exceeds the threshold. Default: **$500/month per module**. Override per stack via `infracost_max_monthly_usd` in the stack's `info.hcl`, or via the environment variable `INFRACOST_MAX_MONTHLY_USD`.

---

### Claude Code / VS Code Hooks (`.vscode/hook-*.sh`)

These scripts integrate with the VS Code + Claude Code environment to enforce guardrails during AI-assisted development:

- **`hook-guard-apply.sh`** — registered as a Claude Code tool hook; prevents the AI agent from executing `terragrunt apply`. Apply must always be triggered manually by the developer.
- **`hook-lint-tf.sh`** — fires on `PostToolUse` whenever a `.tf` file is written; runs TFLint on the edited file immediately.
- **`hook-validate-tf.sh`** — fires on `PostToolUse` whenever a `.tf` file is written; runs `tofu validate` on the containing module if it has been initialized.
- **`hook-test-rego.sh`** — fires on `PostToolUse` whenever a `.rego` policy file is written; re-runs Conftest to verify the updated policy passes against existing fixtures.

---

### GitHub Actions CI (`.github/workflows/ci.yml`)

Triggered on push to `master`, pull requests, and manual dispatch. AWS credentials are obtained via **OIDC federation** — no long-lived static secrets.

Pipeline steps (working directory: `envs/dev/front`):

1. OpenTofu format check (`tofu fmt -check`)
2. AWS OIDC authentication
3. Terragrunt validate
4. TFLint (recursive)
5. Terragrunt plan
6. Infracost cost estimate (JSON + table output)

---

### Running Checks Manually

```bash
# Format
.vscode/run-hclfmt-check.sh

# Lint
.vscode/run-tflint.sh

# Security scan
.vscode/run-checkov-tests.sh

# OPA policies (Terraform)
.vscode/run-conftest.sh

# OPA policies (Terragrunt)
.vscode/run-conftest-tg.sh

# Policy coverage check
.vscode/run-opa-coverage.sh

# Unit tests
.vscode/run-tofu-test.sh

# Validate all initialized modules
.vscode/run-validate-all.sh
```

---

## 🧠 Purpose

This project demonstrates:

- Clean, DRY infrastructure architecture with Terragrunt  
- Secure and validated OpenTofu deployments  
- Environment-specific configurations using layered HCL  
- Real-world patterns for scaling IaC in teams  

---

## 🤝 Contributing

Issues and pull requests are welcome! Feel free to fork, contribute and evolve this as a blueprint for scalable cloud infrastructure.

---

## 👨‍💻 Author

Made by **Thiago Ananias**
