# ==============================================================================
# Security Group (Minimal Attack Surface)
# ==============================================================================

resource "aws_security_group" "app_sg" {
  name        = "careguide-${var.environment}-app-sg"
  description = "Security group for CareGuide assessment web service"
  vpc_id      = data.aws_vpc.default.id

  # Application Web Traffic (Port 8080)
  ingress {
    description = "Allow inbound HTTP traffic to web application"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH Access for deployment automation
  ingress {
    description = "Allow inbound SSH for deployment and administration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound egress (Package installation and container pulls)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "careguide-${var.environment}-app-sg"
    Environment = var.environment
    Project     = "careguide-assessment"
    ManagedBy   = "Terraform"
  }
}
