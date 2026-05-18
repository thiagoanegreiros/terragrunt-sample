variable "env" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "bucket_name" {
  description = "Primary S3 bucket name for the website"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all taggable resources (must include Environment, Project, ManagedBy)"
  type        = map(string)
  default     = {}
}
