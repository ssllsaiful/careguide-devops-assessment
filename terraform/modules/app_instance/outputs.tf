output "instance_id" {
  description = "ID of the provisioned EC2 instance"
  value       = aws_instance.app.id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.app.public_dns
}

output "security_group_id" {
  description = "Security Group ID protecting the instance"
  value       = aws_security_group.app_sg.id
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group capturing container logs"
  value       = aws_cloudwatch_log_group.app_logs.name
}

output "app_url" {
  description = "Full URL to access the deployed web service"
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}"
}
