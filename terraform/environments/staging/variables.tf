variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "careguide-deployer-key"
}

variable "docker_image" {
  description = "Docker image to run"
  type        = string
  default     = "ssllsaiful/devops-task-service:latest"
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "DEBUG"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "app_port" {
  description = "Application HTTP port"
  type        = number
  default     = 8080
}
