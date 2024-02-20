terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
  profile = "hashport-tf-dev"
}

locals {
  project_name = "hiroto-terraform-test"
  origin_id    = "S3Origin"
  notfound     = "notfound.json"
}

resource "random_id" "random_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "bucket" {
  bucket = "${local.project_name}-${random_id.random_id.hex}"
}

resource "aws_s3_object" "notfound" {
  bucket = aws_s3_bucket.bucket.id
  key    = local.notfound
  content = jsonencode({
    message = "Not Found"
  })
  content_type = "application/json"
}

resource "aws_cloudfront_distribution" "distribution" {
  origin {
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = local.origin_id
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "CloudFront Distribution for ${local.project_name}"
  price_class     = "PriceClass_100"
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.origin_id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/${local.notfound}"
    error_caching_min_ttl = 300
  }
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "My CloudFront Origin Access Identity"
}

data "aws_iam_policy_document" "policy_for_cloudfront" {
  statement {
    sid = "AllowCloudFrontServicePrincipal"

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.policy_for_cloudfront.json
}

resource "aws_s3_bucket_cors_configuration" "bucket_cors" {
  bucket = aws_s3_bucket.bucket.id

  cors_rule {
    allowed_headers = []
    expose_headers  = []
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.distribution.domain_name
}

output "bucket_name" {
  value = aws_s3_bucket.bucket.id
}
