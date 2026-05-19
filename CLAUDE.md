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

See [architecture.md](architecture.md) for the full repository structure, module inventory, config hierarchy, and CI/CD details.

## Definition of Done

Before marking any task complete, run these in order and confirm all pass:

```bash
./.vscode/run-tofu-test.sh
./.vscode/run-tflint.sh
./.vscode/run-checkov-tests.sh
./.vscode/run-conftest.sh
```

Then verify:
- [ ] No `.tf` files created outside `common-resources/`
- [ ] No sensitive values hardcoded — account IDs, ARNs, secrets must use SSM Parameter Store
- [ ] Every new or modified variable has `description`, `type`, and `validation` where applicable
- [ ] Every new resource has the required tags or inherits them via `merge()`
- [ ] If a new module was created: `tests/test.tftest.hcl` exists alongside it

## Hard Rules

- **Never create `.tf` resources outside `common-resources/`** — all Terraform logic lives in reusable modules there; `envs/` stacks only hold Terragrunt config.
- **Never edit Terragrunt-generated files** (`provider.tf`, `backend.tf`, `<module-name>.tf` inside `envs/`) — they are overwritten on every run.
- **Never run `terragrunt apply` without explicit user confirmation** — always show the plan and wait for a yes/no before applying.
- **Always run `tofu test` before proposing changes to any module in `common-resources/`** — tests must pass before suggesting the change is safe.
- **Every module in `common-resources/` must ship with `tests/test.tftest.hcl`** — non-negotiable even if not asked. If asked to create a module without tests, create them anyway.
- **Never add skips to `.checkov.yaml` without discussion** — existing skips are intentional trade-offs; new ones require the same justification.
- **Sensitive values must only be referenced via SSM Parameter Store** — never hardcode them in `info.hcl` or any tracked file.