# ==============================================================================
# CloudWatch Log Group with Configurable Retention
# ==============================================================================

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/careguide/${var.environment}/devops-task-service"
  retention_in_days = var.log_retention_days

  tags = {
    Environment = var.environment
    Service     = "devops-task-service"
    Project     = "careguide-assessment"
    ManagedBy   = "Terraform"
  }
}
