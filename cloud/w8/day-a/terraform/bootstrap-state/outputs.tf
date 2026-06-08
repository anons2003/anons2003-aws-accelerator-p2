output "backend_config" {
  description = "Values to copy into ../backend.hcl."
  value = {
    bucket         = aws_s3_bucket.state.bucket
    key            = "final-project/web-app/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.locks.name
    encrypt        = true
  }
}
