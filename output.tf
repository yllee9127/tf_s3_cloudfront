output "bucket_name" {
  value = aws_s3_bucket.static_bucket.id
}

output "website_domain" {
  value = aws_s3_bucket_website_configuration.website.website_domain
}

output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.website.website_endpoint
}
