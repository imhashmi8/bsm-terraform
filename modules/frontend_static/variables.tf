variable "name" {
  description = "Name prefix (e.g., bsm-stg or bsm-prod)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "site_bucket_name" {
  description = "S3 bucket name for frontend"
  type        = string
}

variable "uploads_bucket_name" {
  description = "Optional S3 bucket name for uploads"
  type        = string
  default     = ""
}

variable "alb_domain_name" {
  description = "ALB domain name for API routing"
  type        = string
  default     = ""
}

variable "aliases" {
  description = "CloudFront aliases (CNAMEs)"
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN (must be in us-east-1 for CloudFront)"
  type        = string
  default     = ""
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "api_path_pattern" {
  description = "Path pattern for API routing to ALB"
  type        = string
  default     = "/api/*"
}
