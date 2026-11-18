variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "cloud-backup"
}

variable "backup_retention_days" {
  description = "Number of days before backups expire in S3"
  type        = number
  default     = 14
}

variable "alert_email" {
  description = "Email address for backup failure notifications"
  type        = string
  default     = "" # Set your email address to receive SNS alerts
}
