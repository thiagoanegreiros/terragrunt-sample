package terraform.tags

import rego.v1

required_tags := {"Environment", "Project", "ManagedBy"}

# HCL2 parser wraps resource configs in arrays — access via [_]

skip_types := {
  # IAM — no tag support
  "aws_iam_policy_attachment",
  "aws_iam_role_policy_attachment",
  "aws_iam_role_policy",
  # Route53 / ACM validation — no tag support on these sub-resources
  "aws_route53_record",
  "aws_acm_certificate_validation",
  # CloudFront sub-resources — no tag support
  "aws_cloudfront_function",
  "aws_cloudfront_origin_access_control",
  "aws_cloudfront_origin_access_identity",
  "aws_cloudfront_response_headers_policy",
  # S3 sub-resources — tags only on aws_s3_bucket itself
  "aws_s3_bucket_policy",
  "aws_s3_bucket_public_access_block",
  "aws_s3_bucket_lifecycle_configuration",
  "aws_s3_bucket_server_side_encryption_configuration",
  "aws_s3_bucket_versioning",
  "aws_s3_bucket_cors_configuration",
  "aws_s3_bucket_acl",
  "aws_s3_bucket_website_configuration",
  "aws_s3_bucket_object",
  # WAF — tags managed on the top-level resource
  "aws_wafv2_web_acl_association",
  "aws_wafv2_web_acl_logging_configuration",
  # Cognito sub-resources — no tag support
  "aws_cognito_user_pool_domain",
  "aws_cognito_user_pool_client",
  "aws_cognito_identity_provider",
  # KMS alias — no tag support; tags live on aws_kms_key itself
  "aws_kms_alias",
  # API Gateway V2 sub-resources — no tag support
  "aws_apigatewayv2_integration",
  "aws_apigatewayv2_route",
  # Lambda permission — no tag support
  "aws_lambda_permission",
  # Application Auto Scaling policy — no tag support in AWS provider
  "aws_appautoscaling_policy",
  # SSM data sources parsed as resources in some HCL versions
  "aws_ssm_parameter",
  # S3 ownership controls — no tag support
  "aws_s3_bucket_ownership_controls",
}

deny contains msg if {
  some rtype, rname
  config := input.resource[rtype][rname][_]
  startswith(rtype, "aws_")
  not rtype in skip_types
  not config.tags
  msg := sprintf("[tags] %s.%s: missing 'tags' block — required: %v", [rtype, rname, required_tags])
}

deny contains msg if {
  some rtype, rname
  config := input.resource[rtype][rname][_]
  startswith(rtype, "aws_")
  not rtype in skip_types
  is_object(config.tags)
  missing := required_tags - {k | _ = config.tags[k]}
  count(missing) > 0
  msg := sprintf("[tags] %s.%s: missing required tags %v", [rtype, rname, missing])
}

deny contains msg if {
  some rtype, rname
  config := input.resource[rtype][rname][_]
  startswith(rtype, "aws_")
  not rtype in skip_types
  is_object(config.tags)
  config.tags.ManagedBy != "opentofu"
  msg := sprintf("[tags] %s.%s: ManagedBy must be 'opentofu', got: %s", [rtype, rname, config.tags.ManagedBy])
}
