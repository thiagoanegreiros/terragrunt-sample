#!/bin/bash
set -e
DESIRED_TF_VERSION="1.11.2"

# Check for Homebrew existence
if command -v brew >/dev/null 2>&1; then

    # get user confirmation
    echo "###################################################"
    echo "###################################################"
    echo "The followwing tools will be installed by **Homebrew**"
    echo "- pre-commit
- tflint
- tfenv
- jq"
    echo ""
    echo "Project Terraform version : ${DESIRED_TF_VERSION}"
    echo ""
    echo "Do you want to continue? (yes/no)"
    read -p "Your answer: " confirmation

    if [[ "$confirmation" == "yes" ]]; then
      echo ""
      echo "###################################################"
      echo "Setup Started..."
      echo ""

      # Check if pre-commit is installed
      if ! command -v pre-commit >/dev/null 2>&1; then
          echo "⏳ Installing pre-commit... (https://formulae.brew.sh/formula/pre-commit#default)"
          brew install pre-commit >/dev/null
          echo "✅ pre-commit installed successfully"
      else
          echo "🔄 pre-commit is already installed."
      fi
      echo ""

      # Check if tflint is installed
      if ! command -v tflint >/dev/null 2>&1; then
          echo "⏳ Installing tflint... (https://formulae.brew.sh/formula/tflint#default)"
          brew install tflint >/dev/null
          echo "✅ tflint installed successfully"
      else
          echo "🔄 tflint is already installed."
      fi
      echo ""

      # Check if tfenv is installed
      if ! command -v tfenv >/dev/null 2>&1; then
          echo "⏳ Installing tfenv... (https://formulae.brew.sh/formula/tfenv#default)"
          brew install tfenv >/dev/null
          echo "✅ tfenv installed successfully"
      else
          echo "🔄 tfenv is already installed."
      fi
      echo ""

      # Install and use terraform specific version
      CURRENT_TF_VERSION=$(tfenv version-name  2>/dev/null)
      if [ "${CURRENT_TF_VERSION}" != "${DESIRED_TF_VERSION}" ]; then
          echo "⏳ Installing Terraform version "${DESIRED_TF_VERSION}"..."
          tfenv install "${DESIRED_TF_VERSION}" >/dev/null
          tfenv use "${DESIRED_TF_VERSION}" >/dev/null
          echo "✅ Terraform version "${DESIRED_TF_VERSION}" installed successfully. Using version ${DESIRED_TF_VERSION}."
      else
          tfenv use "${DESIRED_TF_VERSION}" >/dev/null
          echo "🔄 Terraform version "${DESIRED_TF_VERSION}" already in use."
      fi
      echo ""

      # Check if jq (JQuery) is installed
      if ! command -v jq >/dev/null 2>&1; then
          echo "⏳ Installing jq... (https://formulae.brew.sh/formula/jq#default)"
          brew install jq >/dev/null
          echo "✅ jq installed successfully"
      else
          echo "🔄 jq is already installed."
      fi
      echo ""

      # Check if checkov is installed
      if ! command -v checkov >/dev/null 2>&1; then
          echo "⏳ Installing checkov... (https://formulae.brew.sh/formula/checkov#default)"
          brew install checkov >/dev/null
          echo "✅ checkov installed successfully"
      else
          echo "🔄 checkov is already installed."
      fi
      echo ""

    else
        echo "❎ Installation canceled by the user."
        exit 0
    fi
else
    echo "❌ Homebrew not found. Please follow the installation instructions in the readme file to continue."
    exit 1
fi

# Activating hook
echo "⏳ Activating hook..."
pre-commit install >/dev/null
echo "✅ Hook activated successfully."

echo ""
echo "✅ Setup complete!"

echo ""
echo "###################################################"
echo "###################################################"
