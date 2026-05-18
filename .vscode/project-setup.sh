#!/bin/bash
set -e

DESIRED_TF_VERSION="1.11.6"
DESIRED_TG_VERSION="1.0.1"
DESIRED_TGENV_VERSION="1.3.0"

if ! command -v brew >/dev/null 2>&1; then
  echo "❌ Homebrew not found. Please install it first: https://brew.sh"
  exit 1
fi

echo "###################################################"
echo "###################################################"
echo "As seguintes ferramentas serão instaladas via **Homebrew** (+ git para algumas):"
echo "
- pre-commit
- tflint
- tofuenv       → OpenTofu ${DESIRED_TF_VERSION}
- jq
- checkov
- conftest
- tgenv         v${DESIRED_TGENV_VERSION} → Terragrunt ${DESIRED_TG_VERSION}
"
echo "Do you want to continue? (yes/no)"
read -p "Your answer: " confirmation

if [[ "$confirmation" != "yes" ]]; then
  echo "❎ Installation canceled by the user."
  exit 0
fi

echo ""
echo "###################################################"
echo "Setup Started..."
echo ""

# ---------------------------------------------------------------------------
# Homebrew packages
# ---------------------------------------------------------------------------

install_brew() {
  local cmd="$1" formula="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "⏳ Installing ${formula}... (https://formulae.brew.sh/formula/${formula})"
      brew install "$formula" >/dev/null
      echo "✅ ${formula} installed successfully"
  else
      echo "🔄 ${formula} is already installed."
  fi
  echo ""
}

install_brew pre-commit pre-commit
install_brew tflint tflint
install_brew tofuenv tofuenv
install_brew jq jq
install_brew checkov checkov
install_brew conftest conftest

# ---------------------------------------------------------------------------
# tgenv — pinned version via git clone (no brew formula)
# ---------------------------------------------------------------------------

if ! command -v tgenv >/dev/null 2>&1; then
    echo "⏳ Installing tgenv v${DESIRED_TGENV_VERSION}... (https://github.com/tgenv/tgenv)"
    git clone --depth=1 --branch "v${DESIRED_TGENV_VERSION}" https://github.com/tgenv/tgenv.git "${HOME}/.tgenv" >/dev/null 2>&1
    SHELL_CONFIG="${HOME}/.zshrc"
    [[ ! -f "$SHELL_CONFIG" ]] && SHELL_CONFIG="${HOME}/.bashrc"
    grep -qF '.tgenv/bin' "$SHELL_CONFIG" 2>/dev/null || echo 'export PATH="$HOME/.tgenv/bin:$PATH"' >> "$SHELL_CONFIG"
    export PATH="${HOME}/.tgenv/bin:$PATH"
    echo "✅ tgenv v${DESIRED_TGENV_VERSION} installed successfully"
else
    echo "🔄 tgenv is already installed."
fi
echo ""

# ---------------------------------------------------------------------------
# Configure tool versions
# ---------------------------------------------------------------------------

echo "⏳ Configuring OpenTofu ${DESIRED_TF_VERSION}..."
CURRENT_TF_VERSION=$(tofuenv version-name 2>/dev/null || echo "none")
if [[ "$CURRENT_TF_VERSION" != "$DESIRED_TF_VERSION" ]]; then
    tofuenv install "${DESIRED_TF_VERSION}" >/dev/null
    tofuenv use "${DESIRED_TF_VERSION}" >/dev/null
    echo "✅ OpenTofu ${DESIRED_TF_VERSION} installed and active"
else
    tofuenv use "${DESIRED_TF_VERSION}" >/dev/null
    echo "🔄 OpenTofu ${DESIRED_TF_VERSION} already in use."
fi
echo ""

echo "⏳ Configuring Terragrunt ${DESIRED_TG_VERSION}..."
CURRENT_TG_VERSION=$(tgenv version-name 2>/dev/null || echo "none")
if [[ "$CURRENT_TG_VERSION" != "$DESIRED_TG_VERSION" ]]; then
    tgenv install "${DESIRED_TG_VERSION}" >/dev/null
    tgenv use "${DESIRED_TG_VERSION}" >/dev/null
    echo "✅ Terragrunt ${DESIRED_TG_VERSION} installed and active"
else
    tgenv use "${DESIRED_TG_VERSION}" >/dev/null
    echo "🔄 Terragrunt ${DESIRED_TG_VERSION} already in use."
fi
echo ""

# ---------------------------------------------------------------------------
# OpenTofu provider cache
# ---------------------------------------------------------------------------

echo "⏳ Configuring OpenTofu provider cache..."
CACHE_DIR="${HOME}/.terraform.d/plugin-cache"
mkdir -p "$CACHE_DIR"
SHELL_CONFIG="${HOME}/.zshrc"
[[ ! -f "$SHELL_CONFIG" ]] && SHELL_CONFIG="${HOME}/.bashrc"
if ! grep -qF "TF_PLUGIN_CACHE_DIR" "$SHELL_CONFIG" 2>/dev/null; then
    echo '\n# OpenTofu provider cache\nexport TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"' >> "$SHELL_CONFIG"
    echo "✅ TF_PLUGIN_CACHE_DIR configured in ${SHELL_CONFIG}"
else
    echo "🔄 TF_PLUGIN_CACHE_DIR already configured."
fi
echo ""

# ---------------------------------------------------------------------------
# Activate pre-commit hooks
# ---------------------------------------------------------------------------

echo "⏳ Activating hooks..."
pre-commit install --hook-type pre-commit --hook-type pre-push >/dev/null
echo "✅ Hooks activated successfully."

echo ""
echo "✅ Setup complete!"
echo ""
echo "###################################################"
echo "###################################################"
