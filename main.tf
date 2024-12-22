resource "aws_s3_bucket" "static_bucket" {
 bucket = "yls3.sctp-sandbox.com"
 force_destroy = true
}

/*
resource "aws_s3_bucket_acl" "static_bucket_acl" {
  bucket = aws_s3_bucket.static_bucket.id
  acl    = "private"
}
*/

locals {
  s3_origin_id = "ylS3Origin"
}

resource "aws_s3_bucket_public_access_block" "enable_public_access" {
  bucket = aws_s3_bucket.static_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

}

resource "aws_s3_bucket_policy" "allow_public_access" {
  bucket = aws_s3_bucket.static_bucket.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.static_bucket.id

  index_document {
    suffix = "index.html"
  }

}

resource "aws_route53_record" "www" {
 zone_id = data.aws_route53_zone.sctp_zone.zone_id
 name = "yls3" # Bucket prefix before sctp-sandbox.com
 type = "A"

/*
 alias {
   name = aws_s3_bucket_website_configuration.website.website_domain
   zone_id = aws_s3_bucket.static_bucket.hosted_zone_id
   evaluate_target_health = true
 }
 */
  alias {
   name = aws_cloudfront_distribution.s3_distribution.domain_name
   zone_id = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
   evaluate_target_health = true
 }
}

resource "aws_cloudfront_origin_access_control" "cloudfront_oac" {
  name                              = "yls3_couldfront_oac"
  description                       = "Example Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.static_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.cloudfront_oac.id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = false
  comment             = "YL S3 CloudFront"
  default_root_object = "index.html"

  web_acl_id = aws_wafv2_web_acl.yls3-cloudfront-waf.arn

/*
  logging_config {
    include_cookies = false
    bucket          = "yls3.sctp-sandbox.com"
    prefix          = "yls3"
  }
  */

  aliases = ["yls3.sctp-sandbox.com"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

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

  # Optional - Cache behavior with precedence 0
  /*
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }
  */

  # Optional - Cache behavior with precedence 1
  /*
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }
  */

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE", "SG"]
    }
  }

  tags = {
    Environment = "development"
  }

  viewer_certificate {
    # cloudfront_default_certificate = true
    cloudfront_default_certificate = false
    acm_certificate_arn = module.acm.acm_certificate_arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"

  }
}


module "acm" {
  source = "terraform-aws-modules/acm/aws"

  providers = {
    aws = aws.us-east-1
  }

  domain_name = "yls3.sctp-sandbox.com"
  #zone_id     = "Z266PL4W4W6MSG"
  # zone_id = "Z00541411T1NGPV97B5C0"
  zone_id = data.aws_route53_zone.sctp_zone.zone_id
  validation_method = "DNS"

  wait_for_validation = true

  tags = {
    Name = "yls3.sctp-sandbox.com"
  }
}

/*
resource "aws_acm_certificate" "this" {
  domain_name       = "yls3.sctp-sandbox.com"
  validation_method = "DNS"

  tags = {
    "Name"       = "acm-cert-name"
    "costCenter" = "xxxxxxxxx"
    "owner"      = "xxxxxxxxx"
  }

  lifecycle {
    create_before_destroy = true
  }
}
*/