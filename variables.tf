variable "namespace" {
  type        = "string"
  description = "Namespace (e.g. `cp` or `cloudposse`)"
}

variable "stage" {
  type        = "string"
  description = "Stage (e.g. `prod`, `dev`, `staging`)"
}

variable "name" {
  type        = "string"
  description = "Application or solution name (e.g. `app`)"
}

variable "delimiter" {
  type        = "string"
  default     = "-"
  description = "Delimiter to be used between `namespace`, `stage`, `name` and `attributes`"
}

variable "attributes" {
  type        = "list"
  default     = []
  description = "Additional attributes (e.g. `1`)"
}

variable "log_prefix" {
  description = "If the bucket has multiple S3 Bucket logs inside it, provide a prefix to select one"
  default     = ""
}

locals {
  # Strip starting and trailing slashes
  log_prefix_normalised = "${join("/",compact(split("/", var.log_prefix)))}"
}

variable "bucket_name" {
  description = "The name of the s3 bucket with the logs"
}

variable "bucket_encrypted_with_kms" {
  default     = "false"
  description = "If the log bucket is encrypted using AWS KMS Managed keys, specify true"
}
