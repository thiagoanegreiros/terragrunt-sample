variable "env" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be one of: dev, staging, prod"
  }
}

variable "tags" {
  description = "Tags to apply to all resources. Must include Environment, Project, and ManagedBy."
  type        = map(string)
  validation {
    condition     = contains(keys(var.tags), "Environment") && contains(keys(var.tags), "Project") && contains(keys(var.tags), "ManagedBy")
    error_message = "tags must include Environment, Project, and ManagedBy"
  }
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.function_name))
    error_message = "function_name must contain only alphanumeric characters, hyphens, and underscores"
  }
}

variable "lambda_source_dir" {
  description = "Absolute path to the Node.js project directory (must contain package.json and be the src/ subfolder of the stack)"
  type        = string
}

variable "handler" {
  description = "Lambda function handler in the format filename.functionName (e.g. index.handler)"
  type        = string
  default     = "index.handler"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+\\.[a-zA-Z0-9_]+$", var.handler))
    error_message = "handler must be in the format filename.functionName"
  }
}

variable "node_runtime" {
  description = "Node.js runtime version for the Lambda function"
  type        = string
  default     = "nodejs22.x"
  validation {
    condition     = contains(["nodejs18.x", "nodejs20.x", "nodejs22.x"], var.node_runtime)
    error_message = "node_runtime must be one of: nodejs18.x, nodejs20.x, nodejs22.x"
  }
}

variable "memory_size" {
  description = "Lambda function memory allocation in MB (128–10240)"
  type        = number
  default     = 256
  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size must be between 128 and 10240 MB"
  }
}

variable "timeout" {
  description = "Lambda function timeout in seconds (1–900)"
  type        = number
  default     = 30
  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "timeout must be between 1 and 900 seconds"
  }
}

variable "environment_variables" {
  description = "Environment variables to pass to the Lambda function. Sensitive values must come from SSM Parameter Store, not hardcoded here."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log group retention period in days"
  type        = number
  default     = 7
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention value"
  }
}
