#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🔍 Checking HCL formatting (terragrunt hcl fmt --check)..."
cd "$REPO_ROOT"

terragrunt hcl fmt --check --no-color --no-tips --exclude-dir .terraform

echo "✅ HCL format check passed"
