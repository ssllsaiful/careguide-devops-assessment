output "instance_id" {
  description = "EC2 Instance ID"
  value       = module.app_instance.instance_id
}

output "public_ip" {
  description = "Public IP Address"
  value       = module.app_instance.public_ip
}

output "public_dns" {
  description = "Public DNS Name"
  value       = module.app_instance.public_dns
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group"
  value       = module.app_instance.cloudwatch_log_group
}

output "app_url" {
  description = "Direct Application URL"
  value       = module.app_instance.app_url
}
