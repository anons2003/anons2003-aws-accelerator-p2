variable "aws_region" {
  description = "AWS region for Terraform backend resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix used for backend resources."
  type        = string
  default     = "final-web-app"
}

variable "tags" {
  description = "Extra tags applied to backend resources."
  type        = map(string)
  default     = {}
}
