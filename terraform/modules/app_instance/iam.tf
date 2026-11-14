# ==============================================================================
# IAM Role and Instance Profile (Least Privilege - No Static Keys)
# ==============================================================================

resource "aws_iam_role" "app_role" {
  name = "careguide-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = "careguide-assessment"
    ManagedBy   = "Terraform"
  }
}

# Policy scoped strictly to CloudWatch Logs and ECR pull
resource "aws_iam_role_policy" "cloudwatch_and_ecr" {
  name = "careguide-${var.environment}-least-privilege-policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs writing permissions
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.app_logs.arn}:*"
      },
      # Minimum ECR permissions for container image retrieval
      {
        Sid    = "ECRImagePullAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach AWS Systems Manager (SSM) managed policy for secure shell access without open SSH
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "careguide-${var.environment}-instance-profile"
  role = aws_iam_role.app_role.name
}
