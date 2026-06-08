output "web_public_ip" {
  description = "The public IP address of the web server"
  value       = aws_instance.web.public_ip
}

output "s3_bucket_name" {
  description = "The name of the static assets S3 bucket"
  value       = aws_s3_bucket.static_assets.id
}

output "db_endpoint" {
  description = "The database endpoint address"
  value       = aws_db_instance.db.endpoint
}
