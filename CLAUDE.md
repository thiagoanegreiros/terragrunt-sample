# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Infrastructure-as-Code project using Terragrunt over Terraform to deploy a static website infrastructure on AWS (S3 + CloudFront + WAF + ACM). The repository demonstrates environment inheritance, modular structure, and automated validation.

## Common Commands

### Terragrunt Operations

```bash
# Run from within an environment stack directory, e.g. envs/dev/front/
terragrunt init
terragrunt plan
terragrunt apply
terragrunt destroy

# Run across all stacks in an environment
cd envs/dev && terragrunt run-all plan
cd envs/dev && terragrunt run-all apply
```

### Validation & Linting

```bash
# Format check (run from repo root)
terraform fmt -check -recursive

# TFLint (run from module directory)
tflint --config=../../.tflint.hcl

# Or use the VS Code task script
.vscode/run-tflint.sh

# Checkov security scan
checkov --config-file .checkov.yaml
# Or:
.vscode/run-checkov-tests.sh

# Terraform tests
.vscode/run-tftests.sh
```

### Infracost

```bash
# Cost estimation (requires INFRACOST_API_KEY)
infracost breakdown --path envs/dev/front
```

### Tool Setup

```bash
# Install all required tools (tfenv, terraform, tflint, checkov, pre-commit)
.vscode/project-setup.sh
```

## Architecture

### Directory Layout

```
root.hcl                    # Root Terragrunt config — provider, backend, hooks, tags
envs/
  project.hcl               # Shared project variables (project_name)
  dev/
    env.hcl                 # Environment-specific vars (env name, AWS region)
    front/terragrunt.hcl    # CloudFront/S3 stack config for dev
    back/terragrunt.hcl     # Backend stack config for dev
  prod/
    env.hcl
    front/terragrunt.hcl
    back/terragrunt.hcl
common-resources/
  website.hcl               # Terragrunt module wrapper
  website/                  # Reusable Terraform module
    main.tf                 # All AWS resources
    variables.tf
    outputs.tf
```

### Terragrunt Inheritance Pattern

Each stack's `terragrunt.hcl` reads config up the directory tree:

1. `root.hcl` — AWS provider generation, S3 remote state backend, tflint/checkov hooks, default tags
2. `envs/project.hcl` — project name (`ta-tg-sample`)
3. `envs/{env}/env.hcl` — environment name and AWS region
4. Stack-level `info.hcl` — stack-specific variables

Remote state is automatically namespaced: bucket `tf-{project}-{env}-{region}`, key `{relative_path}/terraform.tfstate`.

### Website Module (`common-resources/website/`)

Deploys a complete static website stack:
- **S3**: Primary bucket + backup bucket for failover + logs bucket (all KMS-encrypted, versioned, public access blocked)
- **CloudFront**: Origin failover (primary → backup S3), OAI for private S3 access, TLS 1.2+, geo-restriction to Brazil (BR), security headers policy
- **WAF v2**: Rate limiting (500 req/5min per IP), AWS Managed Rules (KnownBadInputs, CommonRuleSet, AnonymousIpList)
- **Kinesis Firehose**: WAF log delivery to S3 (GZIP-compressed, CMK-encrypted)

### CI/CD (GitHub Actions — `.github/workflows/ci.yml`)

Triggered on push to master, PRs, and manual dispatch. Authenticates to AWS via OIDC (no static credentials). Steps: format check → AWS auth → validate/lint → init → plan → Infracost cost estimate. Working directory: `envs/dev/front`.

GitLab CI (`.gitlab-ci.yml`) is solely for mirroring this repo from GitHub to GitLab on a schedule.

### Pre-commit Hooks

Hooks run on `pre-push` (not pre-commit) and execute TFLint, Terraform tests, and Checkov in sequence. Configured in `.pre-commit-config.yaml`.

## Tool Versions

- Terraform: `>= 1.11.2` (CI uses 1.11.3; local install via `tfenv` at 1.11.2)
- AWS provider: `~> 5.91`
- TFLint AWS plugin: `v0.38.0`
- Checkov: `3.2.410` (in CI)

## Skipped Checkov Rules

Documented in `.checkov.yaml` with reasons:
- `CKV_AWS_18` — S3 access logging (cost decision)
- `CKV2_AWS_42` — CloudFront custom domain
- `CKV2_AWS_62` — S3 event notifications
- `CKV_AWS_144` — S3 cross-region replication
