# variables.tf
variable "aws_profile" {
  type        = string
  description = "The AWS SSO Profile name to use for authentication"
  default     = "dung-iam" # Đổi từ profile cũ sang "dung-iam"
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy infrastructure"
  default     = "us-west-2"
}

variable "instance_type" {
  type        = string
  description = "EC2 Instance type (must be at least 2 vCPUs and 4GB RAM for Minikube)"
  default     = "t3.medium"
}

variable "key_name" {
  type        = string
  description = "Name of the generated SSH Key pair"
  default     = "k8s-minikube-key"
}

variable "app_port" {
  type        = number
  description = "Port exposed by the EC2 host for the application"
  default     = 80
}

variable "node_port" {
  type        = number
  description = "Kubernetes NodePort to expose the application"
  default     = 30000
}
