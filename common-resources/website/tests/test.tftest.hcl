mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-role"
    }
  }
  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-east-1:123456789012:key/mock-kms-key-id"
    }
  }
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn                         = "arn:aws:s3:::mock-bucket"
      bucket_regional_domain_name = "mock-bucket.s3.us-east-1.amazonaws.com"
      bucket_domain_name          = "mock-bucket.s3.amazonaws.com"
    }
  }
  mock_resource "aws_wafv2_rule_group" {
    defaults = {
      arn = "arn:aws:wafv2:us-east-1:123456789012:global/rulegroup/mock-rule-group/mock-id"
    }
  }
  mock_resource "aws_kinesis_firehose_delivery_stream" {
    defaults = {
      arn = "arn:aws:firehose:us-east-1:123456789012:deliverystream/mock-stream"
    }
  }
  mock_resource "aws_wafv2_web_acl" {
    defaults = {
      arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/mock-acl/mock-id"
    }
  }
  mock_resource "aws_cloudfront_origin_access_identity" {
    defaults = {
      iam_arn                         = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity mock"
      cloudfront_access_identity_path = "origin-access-identity/cloudfront/mock"
    }
  }
}

variables {
  bucket_name = "my-site-bucket"
  env         = "dev"
  tags = {
    Environment = "dev"
    Project     = "ta-tg-sample"
    ManagedBy   = "opentofu"
  }
}

run "website_core_plan" {
  command = plan

  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
      user_id    = "AIDIODR4TAW7CSEXAMPLE"
    }
  }

  override_data {
    target = data.aws_cloudfront_response_headers_policy.security_headers
    values = {
      id = "67f7725e-6ac1-4c33-9c99-b5f7a7741fc3"
    }
  }

  # ------------------------
  # S3 (bucket principal)
  # ------------------------
  assert {
    condition     = aws_s3_bucket.site_bucket.bucket == var.bucket_name
    error_message = "S3 bucket principal com nome inesperado"
  }
  assert {
    condition     = aws_s3_bucket_versioning.site_bucket.versioning_configuration[0].status == "Enabled"
    error_message = "Versionamento do bucket principal não está Enabled"
  }
  assert {
    condition = anytrue([
      for r in aws_s3_bucket_server_side_encryption_configuration.site_bucket_sse.rule :
      try(r.apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms", false)
    ])
    error_message = "SSE do bucket principal não está em aws:kms"
  }
  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.public_access.block_public_acls,
      aws_s3_bucket_public_access_block.public_access.block_public_policy,
      aws_s3_bucket_public_access_block.public_access.ignore_public_acls,
      aws_s3_bucket_public_access_block.public_access.restrict_public_buckets
    ])
    error_message = "Public access block do bucket principal não está totalmente ativo"
  }
  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.site_bucket_lifecycle.rule[1].abort_incomplete_multipart_upload[0].days_after_initiation == 7
    error_message = "Lifecycle do bucket principal (abort uploads) não está em 7 dias"
  }
  assert {
    condition     = aws_s3_bucket_website_configuration.site.index_document[0].suffix == "index.html"
    error_message = "Index document do website não é index.html"
  }
  assert {
    condition     = aws_s3_bucket_website_configuration.site.error_document[0].key == "index.html"
    error_message = "Error document do website não é index.html"
  }

  # ------------------------
  # S3 (logs do CloudFront)
  # ------------------------
  assert {
    condition     = aws_s3_bucket.cloudfront_logs.bucket == "${var.bucket_name}-cf-logs"
    error_message = "Bucket de logs do CloudFront com nome inesperado"
  }
  assert {
    condition     = aws_s3_bucket_versioning.cloudfront_logs_versioning.versioning_configuration[0].status == "Enabled"
    error_message = "Versionamento do bucket de logs do CloudFront não está Enabled"
  }
  assert {
    condition = anytrue([
      for r in aws_s3_bucket_server_side_encryption_configuration.cloudfront_logs_sse.rule :
      try(r.apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms", false)
    ])
    error_message = "SSE do bucket de logs do CloudFront não está em aws:kms"
  }
  assert {
    condition = anytrue([
      for r in aws_s3_bucket_lifecycle_configuration.cloudfront_logs_bucket_lifecycle.rule :
      try(r.expiration[0].days, 0) == 90
    ])
    error_message = "Lifecycle do bucket de logs do CloudFront não possui expiração de 90 dias"
  }

  # ------------------------
  # S3 (backup)
  # ------------------------
  assert {
    condition     = aws_s3_bucket.backup_site_bucket.bucket == "${var.bucket_name}-backup"
    error_message = "Bucket de backup com nome inesperado"
  }
  assert {
    condition     = aws_s3_bucket_versioning.backup_site_bucket_versioning.versioning_configuration[0].status == "Enabled"
    error_message = "Versionamento do bucket de backup não está Enabled"
  }
  assert {
    condition = anytrue([
      for r in aws_s3_bucket_server_side_encryption_configuration.backup_site_bucket_sse.rule :
      try(r.apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms", false)
    ])
    error_message = "SSE do bucket de backup não está em aws:kms"
  }
  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.backup_site_bucket_lifecycle.rule[1].abort_incomplete_multipart_upload[0].days_after_initiation == 7
    error_message = "Lifecycle do bucket de backup (abort uploads) não está em 7 dias"
  }

  # ------------------------
  # CloudFront Distribution
  # ------------------------
  assert {
    condition     = aws_cloudfront_distribution.cdn.enabled == true
    error_message = "CloudFront Distribution não está habilitado"
  }
  assert {
    condition     = aws_cloudfront_distribution.cdn.default_cache_behavior[0].target_origin_id == "FailoverGroup"
    error_message = "Default cache behavior não aponta para o FailoverGroup"
  }
  assert {
    condition = alltrue([
      anytrue([for o in aws_cloudfront_distribution.cdn.origin : o.origin_id == "PrimaryS3"]),
      anytrue([for o in aws_cloudfront_distribution.cdn.origin : o.origin_id == "SecondaryS3"])
    ])
    error_message = "Origens PrimaryS3 e/ou SecondaryS3 não foram configuradas"
  }
  assert {
    condition     = contains(aws_cloudfront_distribution.cdn.restrictions[0].geo_restriction[0].locations, "BR")
    error_message = "Geo restriction do CloudFront não contém BR"
  }
  assert {
    condition     = aws_cloudfront_distribution.cdn.viewer_certificate[0].minimum_protocol_version == "TLSv1.2_2021"
    error_message = "Minimum protocol version do CloudFront não é TLSv1.2_2021"
  }

  # ------------------------
  # WAF
  # ------------------------
  assert {
    condition     = aws_wafv2_rule_group.ddos_protection.scope == "CLOUDFRONT"
    error_message = "Rule group de WAF não está com scope CLOUDFRONT"
  }
  assert {
    condition     = aws_wafv2_web_acl.cloudfront_waf.scope == "CLOUDFRONT"
    error_message = "WebACL do CloudFront não está com scope CLOUDFRONT"
  }

  # ------------------------
  # Firehose + S3 (waf-logs)
  # ------------------------
  assert {
    condition     = aws_kinesis_firehose_delivery_stream.waf_logs.destination == "extended_s3"
    error_message = "Firehose não está configurado com destino extended_s3"
  }
  assert {
    condition     = aws_iam_role.firehose_role.name == "firehose-role"
    error_message = "Role do Firehose com nome inesperado"
  }
  assert {
    condition = anytrue([
      for r in aws_s3_bucket_server_side_encryption_configuration.waf_logs_sse.rule :
      try(r.apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms", false)
    ])
    error_message = "SSE do bucket waf_logs não está em aws:kms"
  }
  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.waf_logs_public_access.block_public_acls,
      aws_s3_bucket_public_access_block.waf_logs_public_access.block_public_policy,
      aws_s3_bucket_public_access_block.waf_logs_public_access.ignore_public_acls,
      aws_s3_bucket_public_access_block.waf_logs_public_access.restrict_public_buckets
    ])
    error_message = "Public access block do bucket waf_logs não está totalmente ativo"
  }
  assert {
    condition = anytrue([
      for r in aws_s3_bucket_lifecycle_configuration.waf_logs_bucket_lifecycle.rule :
      try(r.expiration[0].days, 0) == 90
    ])
    error_message = "Lifecycle do bucket waf_logs não possui expiração de 90 dias"
  }

  # ------------------------
  # Tags obrigatórias
  # ------------------------
  assert {
    condition     = aws_s3_bucket.site_bucket.tags["ManagedBy"] == "opentofu"
    error_message = "Tag ManagedBy do bucket principal não é 'opentofu'"
  }
  assert {
    condition     = aws_s3_bucket.site_bucket.tags["Environment"] == var.env
    error_message = "Tag Environment do bucket principal não corresponde ao env"
  }
}
