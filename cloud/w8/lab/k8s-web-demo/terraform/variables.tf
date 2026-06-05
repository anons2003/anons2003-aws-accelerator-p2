variable "aws_region" {
  description = "AWS region for the demo stack."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix used for AWS resources."
  type        = string
  default     = "k8s-web-demo"
}

variable "instance_type" {
  description = "EC2 instance type. t3.medium is recommended for Docker + minikube."
  type        = string
  default     = "t3.medium"
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the EC2 instance. Replace the default with your public IP CIDR for safer use."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Extra tags applied to AWS resources."
  type        = map(string)
  default     = {}
}
