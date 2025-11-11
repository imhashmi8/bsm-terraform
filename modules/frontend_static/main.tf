locals {
  have_uploads = var.uploads_bucket_name != ""
  have_api     = var.alb_domain_name != ""
  have_aliases = length(var.aliases) > 0 && var.acm_certificate_arn != ""
}

# ---------------- S3 buckets ----------------

resource "aws_s3_bucket" "site" {
  bucket = var.site_bucket_name
  tags   = merge(var.tags, { Name = var.site_bucket_name })
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "uploads" {
  count  = local.have_uploads ? 1 : 0
  bucket = var.uploads_bucket_name
  tags   = merge(var.tags, { Name = var.uploads_bucket_name })
}

resource "aws_s3_bucket_ownership_controls" "uploads" {
  count  = local.have_uploads ? 1 : 0
  bucket = aws_s3_bucket.uploads[0].id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  count                   = local.have_uploads ? 1 : 0
  bucket                  = aws_s3_bucket.uploads[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Optional: enable CORS on uploads bucket
resource "aws_s3_bucket_cors_configuration" "uploads" {
  count  = local.have_uploads ? 1 : 0
  bucket = aws_s3_bucket.uploads[0].id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "HEAD"]
    allowed_origins = ["*"]  # tighten to your CloudFront domain later
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# ---------------- CloudFront Origin Access Control ----------------

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.name}-oac-site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "uploads" {
  count                             = local.have_uploads ? 1 : 0
  name                              = "${var.name}-oac-uploads"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ---------------- CloudFront Distribution ----------------

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = "${var.name} static site"
  is_ipv6_enabled     = true
  price_class         = var.price_class
  default_root_object = "index.html"

  # Frontend origin
  origin {
    origin_id   = "s3-site"
    domain_name = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  # Uploads origin (optional)
  dynamic "origin" {
    for_each = local.have_uploads ? [1] : []
    content {
      origin_id   = "s3-uploads"
      domain_name = aws_s3_bucket.uploads[0].bucket_regional_domain_name
      origin_access_control_id = aws_cloudfront_origin_access_control.uploads[0].id
    }
  }

  # ALB origin (optional)
  dynamic "origin" {
    for_each = local.have_api ? [1] : []
    content {
      origin_id   = "alb-origin"
      domain_name = var.alb_domain_name
      custom_origin_config {
        origin_protocol_policy = "https-only"
        http_port              = 80
        https_port             = 443
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # Default behavior (frontend)
  default_cache_behavior {
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.cors_s3.id
  }

  # /uploads/*
  dynamic "ordered_cache_behavior" {
    for_each = local.have_uploads ? ["/uploads/*"] : []
    content {
      path_pattern           = ordered_cache_behavior.value
      target_origin_id       = "s3-uploads"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET","HEAD","OPTIONS"]
      cached_methods         = ["GET","HEAD","OPTIONS"]
      compress               = true
      cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.cors_s3.id
    }
  }

  # /api/* → ALB
  dynamic "ordered_cache_behavior" {
    for_each = local.have_api ? [var.api_path_pattern] : []
    content {
      path_pattern           = ordered_cache_behavior.value
      target_origin_id       = "alb-origin"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET","HEAD","OPTIONS","PUT","POST","PATCH","DELETE"]
      cached_methods         = ["GET","HEAD","OPTIONS"]
      compress               = true
      cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    }
  }

  # SPA fallback
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = !local.have_aliases
    acm_certificate_arn            = local.have_aliases ? var.acm_certificate_arn : null
    ssl_support_method             = local.have_aliases ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  aliases = local.have_aliases ? var.aliases : []
  tags    = var.tags
}

# ---------------- Bucket policies ----------------

data "aws_iam_policy_document" "site" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
    principals { 
        type = "Service" 
        identifiers = ["cloudfront.amazonaws.com"] 
        }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json
}

data "aws_iam_policy_document" "uploads" {
  count = local.have_uploads ? 1 : 0
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.uploads[0].arn}/*"]
    principals { 
        type = "Service" 
        identifiers = ["cloudfront.amazonaws.com"] 
        }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "uploads" {
  count  = local.have_uploads ? 1 : 0
  bucket = aws_s3_bucket.uploads[0].id
  policy = data.aws_iam_policy_document.uploads[0].json
}

# Managed cache/origin policies
data "aws_cloudfront_cache_policy" "caching_optimized" { name = "Managed-CachingOptimized" }
data "aws_cloudfront_cache_policy" "caching_disabled"  { name = "Managed-CachingDisabled" }
data "aws_cloudfront_origin_request_policy" "cors_s3"  { name = "Managed-CORS-S3Origin" }
data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" { name = "Managed-AllViewerExceptHostHeader" }
