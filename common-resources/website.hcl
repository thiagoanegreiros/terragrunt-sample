locals {
  project_vars     = read_terragrunt_config(find_in_parent_folders("project.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  info_vars        = read_terragrunt_config("info.hcl")

  env          = local.environment_vars.locals.environment
  project_name = local.project_vars.locals.project_name
}

generate "website" {
  path      = "website.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
  module "website" {
    source = "${find_in_parent_folders("common-resources/website")}"

    env         = "${local.env}"
    bucket_name = "${local.env}-terragrunt-sample-website"

    tags = {
      Environment = "${local.env}"
      Project     = "${local.project_name}"
      ManagedBy   = "opentofu"
    }
  }

  output "cloudfront" {
    value = module.website.cloudfront_distribution_domain_name
  }
EOF
}
