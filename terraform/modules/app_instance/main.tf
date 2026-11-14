terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Fetch default VPC
data "aws_vpc" "default" {
  default = true
}

# Fetch latest Amazon Linux 2023 AMI (x86_64)
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==============================================================================
# EC2 Deployment Target Instance
# ==============================================================================
resource "aws_instance" "app" {
  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = var.instance_type
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.app_profile.name

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region      = var.aws_region
    environment     = var.environment
    log_level       = var.log_level
    log_group_name  = aws_cloudwatch_log_group.app_logs.name
    docker_image    = var.docker_image
  })

  user_data_replace_on_change = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2 for security hardening
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "careguide-${var.environment}-app-server"
    Environment = var.environment
    Project     = "careguide-assessment"
    ManagedBy   = "Terraform"
  }
}
