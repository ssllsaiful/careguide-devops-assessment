terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "careguide-devops-tfstate-179243013613"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "careguide-devops-tflocks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "production"
      Project     = "careguide-assessment"
      ManagedBy   = "Terraform"
    }
  }
}

module "app_instance" {
  source = "../../modules/app_instance"

  environment        = "production"
  aws_region         = var.aws_region
  instance_type      = var.instance_type
  key_name           = var.key_name
  docker_image       = var.docker_image
  log_level          = var.log_level
  log_retention_days = var.log_retention_days
  app_port           = var.app_port
}
