output "web_url" {
  description = "Public URL of the EC2 web server."
  value       = "http://${aws_instance.web.public_dns}"
}

output "web_public_ip" {
  description = "Public IP of the EC2 web server."
  value       = aws_instance.web.public_ip
}

output "assets_bucket_name" {
  description = "Private S3 bucket used for static assets."
  value       = aws_s3_bucket.assets.bucket
}

output "rds_endpoint" {
  description = "Private RDS MySQL endpoint."
  value       = aws_db_instance.mysql.address
}

output "db_password" {
  description = "Generated RDS password. Stored in Terraform state."
  value       = random_password.db.result
  sensitive   = true
}
