resource "aws_kms_key" "s3_default" {
  description         = "KMS key for S3 default encryption"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "kms-s3-policy",
    Statement: [
      {
        Sid: "AllowRootAccount",
        Effect: "Allow",
        Principal: {
          AWS: "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action: "kms:*",
        Resource: "*"
      }
    ]
  })
}

resource "aws_s3_bucket" "site_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "site_bucket" {
  bucket = aws_s3_bucket.site_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site_bucket_sse" {
  bucket = aws_s3_bucket.site_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_default.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "site_bucket_lifecycle" {
  bucket = aws_s3_bucket.site_bucket.id

  rule {
    id     = "expire-old-objects"
    status = "Enabled"

    expiration {
      days = 90  # apaga objetos após 90 dias
    }

    filter {
      prefix = ""  # aplica a todos os objetos
    }
  }

  rule {
    id     = "abort-failed-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7  # ou 1~30 dias, conforme sua política
    }

    filter {
      prefix = ""
    }
  }
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.site_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs_ownership" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.site_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        AWS = aws_cloudfront_origin_access_identity.oai.iam_arn
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.site_bucket.arn}/*"
    }]
  })
}

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI para CloudFront acessar ${var.bucket_name}"
}

resource "aws_s3_bucket" "cloudfront_logs" {
  bucket = "${var.bucket_name}-cf-logs"
  force_destroy = true

  tags = {
    Name        = "${var.bucket_name}-cf-logs"
    Environment = var.env
  }
}

resource "aws_s3_bucket_versioning" "cloudfront_logs_versioning" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudfront_logs_sse" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_default.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs_bucket_lifecycle" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    id     = "expire-old-objects"
    status = "Enabled"

    expiration {
      days = 90  # apaga objetos após 90 dias
    }

    filter {
      prefix = ""  # aplica a todos os objetos
    }
  }

  rule {
    id     = "abort-failed-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7  # ou 1~30 dias, conforme sua política
    }

    filter {
      prefix = ""
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "cf_logs_policy" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal",
        Effect    = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action   = "s3:PutObject",
        Resource = "${aws_s3_bucket.cloudfront_logs.arn}/cloudfront-logs/*",
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "logs_block" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_wafv2_rule_group" "ddos_protection" {
  name     = "ddos-protection"
  scope    = "CLOUDFRONT"
  capacity = 100

  rule {
    name     = "rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 500
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ddos-protection"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "cloudfront_waf_logging" {
  log_destination_configs = [
    aws_kinesis_firehose_delivery_stream.waf_logs.arn
  ]

  resource_arn = aws_wafv2_web_acl.cloudfront_waf.arn
}

resource "aws_kms_key" "firehose" {
  description         = "KMS key for encrypting Kinesis Firehose stream"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-firehose-policy",
    Statement = [
      {
        Sid       = "Allow root account full access",
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Sid       = "Allow Firehose to use the key",
        Effect    = "Allow",
        Principal = {
          Service = "firehose.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource  = "*",
        Condition = {
          StringEquals = {
            "kms:ViaService" = "firehose.us-east-1.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "firehose_role" {
  name = "firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "firehose.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_s3_bucket" "waf_logs" {
  bucket = "my-waf-logs-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "waf_logs_bucket_versioning" {
  bucket = aws_s3_bucket.waf_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "waf_logs_public_access" {
  bucket = aws_s3_bucket.waf_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "waf_logs_sse" {
  bucket = aws_s3_bucket.waf_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_default.arn
    }
  }
}


resource "aws_s3_bucket_lifecycle_configuration" "waf_logs_bucket_lifecycle" {
  bucket = aws_s3_bucket.waf_logs.id

  rule {
    id     = "expire-old-objects"
    status = "Enabled"

    expiration {
      days = 90  # apaga objetos após 90 dias
    }

    filter {
      prefix = ""  # aplica a todos os objetos
    }
  }

  rule {
    id     = "abort-failed-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7  # ou 1~30 dias, conforme sua política
    }

    filter {
      prefix = ""
    }
  }
}

resource "aws_kinesis_firehose_delivery_stream" "waf_logs" {
  name        = "waf-logs"
  destination = "extended_s3"
  server_side_encryption {
    enabled = true
    key_type    = "CUSTOMER_MANAGED_CMK"
    key_arn     = aws_kms_key.firehose.arn
  }

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.waf_logs.arn
    buffering_size     = 5
    buffering_interval = 300
    compression_format = "GZIP"
    kms_key_arn        = aws_kms_key.firehose.arn
  }
}

resource "aws_wafv2_web_acl" "cloudfront_waf" {
  name        = "cloudfront-waf"
  scope       = "CLOUDFRONT"
  description = "WAF with DDOS"

  default_action {
    block {}
  }

  rule {
    name     = "ddos-protection"
    priority = 1

    statement {
      rule_group_reference_statement {
        arn = aws_wafv2_rule_group.ddos_protection.arn
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ddos-protection"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 200
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet-AWSManaged"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 300
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet-AWSManaged"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesAnonymousIpList"
    priority = 400
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAnonymousIpList-AWSManaged"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "cloudfront-waf"
    sampled_requests_enabled   = true
  }
}

resource "aws_s3_bucket" "backup_site_bucket" {
  bucket = "${var.bucket_name}-backup"
}

resource "aws_s3_bucket_versioning" "backup_site_bucket_versioning" {
  bucket = aws_s3_bucket.backup_site_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "backup_site_bucket_public_access" {
  bucket = aws_s3_bucket.backup_site_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup_site_bucket_sse" {
  bucket = aws_s3_bucket.backup_site_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_default.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backup_site_bucket_lifecycle" {
  bucket = aws_s3_bucket.backup_site_bucket.id

  rule {
    id     = "expire-old-objects"
    status = "Enabled"

    expiration {
      days = 90  # apaga objetos após 90 dias
    }

    filter {
      prefix = ""  # aplica a todos os objetos
    }
  }

  rule {
    id     = "abort-failed-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7  # ou 1~30 dias, conforme sua política
    }

    filter {
      prefix = ""
    }
  }
}

resource "aws_s3_bucket_policy" "backup_bucket_policy" {
  bucket = aws_s3_bucket.backup_site_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        AWS = aws_cloudfront_origin_access_identity.oai.iam_arn
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.backup_site_bucket.arn}/*"
    }]
  })
}

data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

resource "aws_cloudfront_distribution" "cdn" {
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.site_bucket.bucket_regional_domain_name
    origin_id   = "PrimaryS3"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  origin {
    domain_name = aws_s3_bucket.backup_site_bucket.bucket_regional_domain_name
    origin_id   = "SecondaryS3"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  origin_group {
    origin_id = "FailoverGroup"

    failover_criteria {
      status_codes = [403, 404, 500, 502, 503, 504]
    }

    member {
      origin_id = "PrimaryS3"
    }

    member {
      origin_id = "SecondaryS3"
    }
  }

  logging_config {
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    prefix          = "cloudfront-logs/"
    include_cookies = false
  }

  enabled = true

  default_cache_behavior {
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
    target_origin_id       = "FailoverGroup"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
  }

  web_acl_id = aws_wafv2_web_acl.cloudfront_waf.arn

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["BR"]
    }
  }
}
