output "app_url" {
  description = "Public URL served by the Application Load Balancer."
  value       = "http://${aws_lb.app.dns_name}"
}

output "alb_dns_name" {
  description = "Raw ALB DNS name."
  value       = aws_lb.app.dns_name
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance for debugging."
  value       = aws_instance.k8s.public_ip
}

output "ssh_private_key_path" {
  description = "Generated private key path for SSH debugging."
  value       = local_sensitive_file.ssh_private_key.filename
}

output "ssh_command" {
  description = "SSH command for debugging the EC2 instance."
  value       = "ssh -i ${local_sensitive_file.ssh_private_key.filename} ec2-user@${aws_instance.k8s.public_ip}"
}
