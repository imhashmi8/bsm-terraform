output "site_bucket_name"         { value = aws_s3_bucket.site.bucket }
output "uploads_bucket_name"      { value = var.uploads_bucket_name != "" ? aws_s3_bucket.uploads[0].bucket : "" }
output "distribution_id"          { value = aws_cloudfront_distribution.this.id }
output "distribution_domain_name" { value = aws_cloudfront_distribution.this.domain_name }
output "distribution_hosted_zone_id" { value = aws_cloudfront_distribution.this.hosted_zone_id }
