variable "name" {
  description = "Prefix/name for RDS resources (e.g. bsm-stg)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the RDS instance will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "allowed_sg_ids" {
  description = "List of security groups allowed to connect to the DB (e.g., ECS Service SG)"
  type        = list(string)
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.13"
}

variable "instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t4g.small"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GiB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage (GiB) for autoscaling"
  type        = number
  default     = 200
}

variable "multi_az" {
  description = "Whether to deploy Multi-AZ"
  type        = bool
  default     = false
}

variable "backup_retention" {
  description = "Backup retention in days"
  type        = number
  default     = 3
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Name of the default database to create"
  type        = string
  default     = "appdb"
}

variable "performance_insights" {
  description = "Enable Performance Insights"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to assign to resources"
  type        = map(string)
  default     = {}
}

variable "skip_final_snapshot" {
  type        = bool
  default     = true   # dev/staging default
  description = "Skip final snapshot on deletion"
}

variable "final_snapshot_identifier" {
  type        = string
  default     = ""
  description = "Final snapshot id when skip_final_snapshot = false"
}