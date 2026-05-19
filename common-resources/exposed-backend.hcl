locals {
  project_vars     = read_terragrunt_config(find_in_parent_folders("project.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  info_vars        = read_terragrunt_config("info.hcl")

  env          = local.environment_vars.locals.environment
  project_name = local.project_vars.locals.project_name
}

generate "exposed_backend" {
  path      = "exposed-backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
  module "exposed_backend" {
    source = "${find_in_parent_folders("common-resources/exposed-backend")}"

    env               = "${local.env}"
    function_name     = "${local.info_vars.locals.function_name}"
    lambda_source_dir = "${get_terragrunt_dir()}/src"

    tags = {
      Environment = "${local.env}"
      Project     = "${local.project_name}"
      ManagedBy   = "opentofu"
    }
  }

  output "api_endpoint" {
    value = module.exposed_backend.api_endpoint
  }

  output "lambda_function_name" {
    value = module.exposed_backend.lambda_function_name
  }
EOF
}
