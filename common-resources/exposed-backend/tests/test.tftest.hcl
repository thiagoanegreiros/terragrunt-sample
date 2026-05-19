mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-exec-role"
    }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:mock"
    }
  }
  mock_resource "aws_lambda_function" {
    defaults = {
      arn        = "arn:aws:lambda:us-east-1:123456789012:function:mock-function"
      invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:mock-function/invocations"
    }
  }
  mock_resource "aws_apigatewayv2_api" {
    defaults = {
      id            = "mock-api-id"
      execution_arn = "arn:aws:execute-api:us-east-1:123456789012:mock-api-id"
    }
  }
  mock_resource "aws_apigatewayv2_stage" {
    defaults = {
      invoke_url = "https://mock-api-id.execute-api.us-east-1.amazonaws.com"
    }
  }
  mock_resource "aws_apigatewayv2_integration" {
    defaults = {
      id = "mock-integration-id"
    }
  }
}

mock_provider "null" {}

variables {
  env               = "dev"
  function_name     = "test-backend"
  lambda_source_dir = "./tests/fixtures/src"
  tags = {
    Environment = "dev"
    Project     = "ta-tg-sample"
    ManagedBy   = "opentofu"
  }
}

run "exposed_backend_plan" {
  command = plan

  override_resource {
    target = null_resource.npm_install
    values = {
      id = "mock-npm-install"
    }
  }

  override_data {
    target = data.archive_file.lambda_zip
    values = {
      output_path         = "/tmp/test-lambda.zip"
      output_base64sha256 = "dGVzdA=="
      output_md5          = "abc123"
    }
  }

  # --- Lambda ---
  assert {
    condition     = aws_lambda_function.this.function_name == var.function_name
    error_message = "Lambda: function_name inesperado"
  }
  assert {
    condition     = aws_lambda_function.this.runtime == var.node_runtime
    error_message = "Lambda: runtime inesperado"
  }
  assert {
    condition     = aws_lambda_function.this.handler == var.handler
    error_message = "Lambda: handler inesperado"
  }
  assert {
    condition     = aws_lambda_function.this.memory_size == var.memory_size
    error_message = "Lambda: memory_size inesperado"
  }
  assert {
    condition     = aws_lambda_function.this.timeout == var.timeout
    error_message = "Lambda: timeout inesperado"
  }
  assert {
    condition     = aws_lambda_function.this.tracing_config[0].mode == "PassThrough"
    error_message = "Lambda: tracing_config mode deve ser PassThrough"
  }

  # --- IAM ---
  assert {
    condition     = aws_iam_role.lambda_exec.name == "${var.function_name}-exec-role"
    error_message = "IAM role: nome inesperado"
  }
  assert {
    condition     = can(jsondecode(aws_iam_role.lambda_exec.assume_role_policy).Statement[0].Principal.Service == "lambda.amazonaws.com")
    error_message = "IAM role: assume_role_policy deve autorizar lambda.amazonaws.com"
  }
  assert {
    condition     = aws_iam_role_policy_attachment.lambda_basic.policy_arn == "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    error_message = "IAM attachment: policy_arn incorreta"
  }

  # --- API Gateway ---
  assert {
    condition     = aws_apigatewayv2_api.this.name == "${var.function_name}-api"
    error_message = "API GW: name inesperado"
  }
  assert {
    condition     = aws_apigatewayv2_api.this.protocol_type == "HTTP"
    error_message = "API GW: protocol_type deve ser HTTP"
  }
  assert {
    condition     = aws_apigatewayv2_stage.default.name == "$default"
    error_message = "API GW stage: name deve ser $default"
  }
  assert {
    condition     = aws_apigatewayv2_stage.default.auto_deploy == true
    error_message = "API GW stage: auto_deploy deve ser true"
  }
  assert {
    condition     = aws_apigatewayv2_integration.lambda.integration_type == "AWS_PROXY"
    error_message = "API GW integration: integration_type deve ser AWS_PROXY"
  }
  assert {
    condition     = aws_apigatewayv2_integration.lambda.payload_format_version == "2.0"
    error_message = "API GW integration: payload_format_version deve ser 2.0"
  }
  assert {
    condition     = aws_apigatewayv2_route.default.route_key == "$default"
    error_message = "API GW route: route_key deve ser $default"
  }

  # --- CloudWatch ---
  assert {
    condition     = aws_cloudwatch_log_group.lambda_logs.name == "/aws/lambda/${var.function_name}"
    error_message = "CloudWatch: nome do log group da Lambda inesperado"
  }
  assert {
    condition     = aws_cloudwatch_log_group.api_logs.name == "/aws/apigateway/${var.function_name}-api"
    error_message = "CloudWatch: nome do log group da API inesperado"
  }
  assert {
    condition     = aws_cloudwatch_log_group.lambda_logs.retention_in_days == var.log_retention_days
    error_message = "CloudWatch: retention_in_days inesperado no log group da Lambda"
  }

  # --- Tags ---
  assert {
    condition     = aws_lambda_function.this.tags["ManagedBy"] == "opentofu"
    error_message = "Tags: ManagedBy deve ser opentofu na Lambda"
  }
  assert {
    condition     = aws_lambda_function.this.tags["Environment"] == var.env
    error_message = "Tags: Environment deve corresponder ao var.env na Lambda"
  }
  assert {
    condition     = aws_apigatewayv2_api.this.tags["ManagedBy"] == "opentofu"
    error_message = "Tags: ManagedBy deve ser opentofu na API GW"
  }
}
