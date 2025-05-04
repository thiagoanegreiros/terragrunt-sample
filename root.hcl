locals {
  env_config_parent = try(read_terragrunt_config(find_in_parent_folders("env.hcl")), null)
  env_config_local  = try(read_terragrunt_config("env.hcl"), null)

  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))
  environment_vars = local.env_config_parent != null ? local.env_config_parent : local.env_config_local

  project_name = local.project_vars.locals.project_name
  region = local.environment_vars.locals.region
  env = local.environment_vars.locals.environment

  key = "${local.project_name}-${local.env}-${local.region}"
  tags = {
    "region": local.region
    "env": local.env,
    "project_name": local.project_name
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"
  default_tags {
    tags = {
${join("\n", [for key, value in local.tags : "      ${key} = \"${value}\""])}
    }
  }
}

terraform {
  required_version = ">= 1.11.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.91"
    }
    null = {
      source = "hashicorp/null"
      version = "3.2.3"
    }
  }
}

EOF
}

remote_state {
  backend = "s3"
  config = {
    region = "${local.region}"
    bucket = "tf-${local.key}"
    key = "${path_relative_to_include()}/terraform.tfstate"
    encrypt = true
    use_lockfile = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

inputs = merge(
  local.project_vars.locals,
  local.environment_vars.locals,
)

terraform {
  before_hook "validate_tf_files" {
    commands = ["plan", "apply"]
    execute  = ["tflint", "--init", "--config=${get_parent_terragrunt_dir()}/.tflint.hcl", "--minimum-failure-severity=error"]
    run_on_error = false
  }
  before_hook "checkov_tf_files" {
    commands = ["plan", "apply"]
    execute = [
      "checkov",
      "--skip-check",
      "CKV_TF_1,CKV_TF_2,CKV2_AWS_31,CKV_AWS_174,CKV2_AWS_6,CKV2_AWS_32,CKV_AWS_174,CKV_AWS_144,CKV_AWS_21,CKV_AWS_145,CKV_AWS_18,CKV2_AWS_61,CKV2_AWS_62,CKV2_AWS_47,CKV2_AWS_42,CKV2_AWS_65,CKV2_AWS_3",
      "-d",
      ".",
      "--quiet",
      "--framework",
      "terraform"
    ]
    run_on_error = false
  }
}
