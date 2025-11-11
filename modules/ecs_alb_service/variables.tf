variable "name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "desired_count" {
  type    = number
  default = 2
}
variable "container_port" {
  type    = number
  default = 80
}
variable "image" {
  description = "Full container image URI (e.g., x.dkr.ecr.region.amazonaws.com/repo:tag)"
  type        = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "region" { type = string }

variable "alb_certificate_arn" {
  description = "ACM certificate ARN in the same region as the ALB (for HTTPS listener)"
  type        = string
  default     = ""
}


variable "health_check_path" {
  description = "Target group health check path"
  type        = string
  default     = "/"
}