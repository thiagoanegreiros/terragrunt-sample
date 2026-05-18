# ☁️ Infrastructure as Code with Terragrunt & Terraform

![CI](https://github.com/thiagoanegreiros/terragrunt-sample/actions/workflows/ci.yml/badge.svg)
![Terraform](https://img.shields.io/badge/Terraform-1.6+-blueviolet)
![Terragrunt](https://img.shields.io/badge/Terragrunt-0.56+-blue)
![Checkov](https://img.shields.io/badge/Checkov-passed-brightgreen)
![TFLint](https://img.shields.io/badge/TFLint-configured-informational)
![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen.svg)

This is an **Infrastructure-as-Code (IaC)** project using **Terragrunt** over **Terraform**, designed to deploy a modular and versioned AWS infrastructure with CI/CD validation.

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
- ✅ Modular Terraform using local structure  
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

## 🔍 Static Analysis & Hooks

To run all security and linting checks manually:

```bash
tflint --init
checkov -d . --quiet
```

To install pre-commit hooks:

```bash
pre-commit install
```

---

## 🧠 Purpose

This project demonstrates:

- Clean, DRY infrastructure architecture with Terragrunt  
- Secure and validated Terraform deployments  
- Environment-specific configurations using layered HCL  
- Real-world patterns for scaling IaC in teams  

---

## 🤝 Contributing

Issues and pull requests are welcome! Feel free to fork, contribute and evolve this as a blueprint for scalable cloud infrastructure.

---

## 👨‍💻 Author

Made by **Thiago Ananias**
