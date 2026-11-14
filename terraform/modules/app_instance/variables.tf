variable "environment" {
  description = "Target environment name (staging or production)"
  type        = string
}

variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance size (Free tier eligible: t2.micro or t3.micro)"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "SSH key pair name for EC2 access"
  type        = string
  default     = "careguide-deployer-key"
}

variable "docker_image" {
  description = "Docker image repository and tag to deploy"
  type        = string
  default     = "ssllsaiful/devops-task-service:latest"
}

variable "log_level" {
  description = "Application logging level"
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
}

variable "app_port" {
  description = "Port exposed by the web service"
  type        = number
  default     = 8080
}
