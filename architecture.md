# Repository Architecture

## Config Hierarchy

Terragrunt merges config top-down at runtime. Each stack inherits from parent files:

```
root.hcl                        ← providers, remote state, before_hooks (tflint/checkov/infracost)
envs/
  project.hcl                   ← project_name (ta-tg-sample)
  <env>/
    env.hcl                     ← environment name, AWS region
    <stack>/
      info.hcl                  ← module-specific input values (may be empty)
      terragrunt.hcl            ← includes root.hcl + module wrapper .hcl
```

The computed `key = "${project_name}-${env}-${region}"` drives the S3 state bucket (`tf-<key>`). The state key path is `${path_relative_to_include()}/terraform.tfstate`. There is no DynamoDB lock table configured.

---

## Common Resources (Reusable Modules)

Modules live in `common-resources/<name>/` and are pure Terraform (no Terragrunt).

Each module has a sibling `<name>.hcl` Terragrunt wrapper that:
1. Reads `info.hcl` from the deployment directory for inputs.
2. Uses a `generate` block to write an inline `.tf` file that calls the TF module.

### Existing modules

**website** — static website stack

```
common-resources/
  website.hcl       # HCL wrapper → generates website.tf, calls website/ module
  website/
    main.tf
    variables.tf
    outputs.tf
    tests/test.tftest.hcl
```

Deploys:
- **S3**: Primary bucket + backup bucket for failover + logs bucket (all KMS-encrypted, versioned, public access blocked)
- **CloudFront**: Origin failover (primary → backup S3), OAI for private S3 access, TLS 1.2+, geo-restriction to Brazil (BR), security headers policy
- **WAF v2**: Rate limiting (500 req/5min per IP), AWS Managed Rules (KnownBadInputs, CommonRuleSet, AnonymousIpList)
- **Kinesis Firehose**: WAF log delivery to S3 (GZIP-compressed, CMK-encrypted)

---

## Environments (Deployments)

```
envs/
  project.hcl
  dev/
    env.hcl                 ← environment=dev, region=us-east-1
    front/
      info.hcl
      terragrunt.hcl        ← root.hcl + website.hcl
    back/
      info.hcl
      terragrunt.hcl        ← root.hcl + backend.hcl (module TBD)
  prod/
    env.hcl
    front/
      info.hcl
      terragrunt.hcl
    back/
      info.hcl
      terragrunt.hcl
```

---

## Policies (OPA/Rego)

Conftest policies enforce conventions at CI and pre-push time:

```
policies/
  terraform/
    module_score.rego         # Module quality scoring
    module_score_test.rego
    no_public_acl.rego        # Block public S3 ACLs
    required_tags.rego        # Enforce required resource tags
    variable_contract.rego    # Enforce variable description/type/validation
  terragrunt/
    generate_block_contract.rego  # Enforce generate block conventions
    no_hardcoded_ids.rego         # Block hardcoded account IDs / ARNs
```

---

## Generated Files (git-ignored)

Terragrunt generates these files inside each deployment stack — **do not edit manually**:
- `provider.tf`
- `backend.tf`
- `<module-name>.tf` (e.g., `website.tf`)

All `envs/**/*.tf` files are in `.gitignore`.

---

## CI/CD (GitHub Actions — `.github/workflows/ci.yml`)

Triggered on push to master, PRs, and manual dispatch. Authenticates to AWS via OIDC (no static credentials). Steps: format check → AWS auth → validate → TFLint → init → plan → Infracost cost estimate. Working directory: `envs/dev/front`.

---

## Pre-commit Hooks

Hooks run on `pre-push` (not pre-commit) and execute TFLint, Terraform tests, and Checkov in sequence. Configured in `.pre-commit-config.yaml`.

---

## Tool Versions

- OpenTofu: `>= 1.9.0` (CI uses `1.9.1` via `opentofu/setup-opentofu@v1`)
- AWS provider: `6.43.0`
- TFLint AWS plugin: `v0.38.0`
- Checkov: `3.2.410` (in CI)
