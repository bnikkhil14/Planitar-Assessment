provider "aws" {
  region = "us-east-1"
  access_key = "AKIA3ODFABMHRBO3QKPX"
  secret_key = "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"  
}

variable "domain_name" {
  description = "domain name"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "tags for all the resources, if any"
}

variable "hosted_zone" {
  default     = null
  description = "Route53 hosted zone"
}

variable "acm_certificate_domain" {
  default     = null
  description = "Domain of the ACM certificate"
}

variable "price_class" {
  default     = "PriceClass_100"
  description = "CloudFront distribution price class"
}

variable "use_default_domain" {
  default     = false
  description = "Use CloudFront website address without Route53 and ACM certificate"
}

variable "upload_sample_file" {
  default     = false
  description = "Upload sample html file to s3 bucket"
}

variable "archive_path" {}

variable "name" {
  description = "Function name"
}
variable "handler_name" {
  description = "Handler name prefix."
}
variable "memory_limit" {
  default = "128"
}
variable "timeout" {
  default = "10"
}

variable "runtime" {
  default = "nodejs10.x"
}

variable "cidr_whitelist" {
    description = "IPs to whitelist in WAF"
}

locals {
  acl_id         = "_app_rules"
  metric_name    = "apprules"
  name           = var.name
  runtime        = var.runtime
  handler_name   = var.handler_name
  lambda_archive = var.archive_path
  memory_limit   = var.memory_limit
  timeout        = var.timeout
  default_certs = var.use_default_domain ? ["default"] : []
  acm_certs     = var.use_default_domain ? [] : ["acm"]
  domain_name   = var.use_default_domain ? [] : [var.domain_name]
  content_type_map = {
    html        = "text/html",
    js          = "application/javascript",
    css         = "text/css",
    svg         = "image/svg+xml",
    jpg         = "image/jpeg",
    ico         = "image/x-icon",
    png         = "image/png",
    gif         = "image/gif",
    pdf         = "application/pdf"
  }
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "access-identity-${var.domain_name}.s3.amazonaws.com"
}

data "aws_iam_policy_document" "lambda_role" {
  statement {
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com",
        "edgelambda.amazonaws.com"
      ]
    }
    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_role" "lambda" {
  name               = "${title(local.name)}Lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_access_to_write_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_lambda_function" "lambda" {
  filename         = local.lambda_archive
  function_name    = local.name
  role             = aws_iam_role.lambda.arn
  handler          = local.handler_name
  source_code_hash = filebase64sha256(local.lambda_archive)
  runtime          = local.runtime
  publish          = "true"
}


resource "aws_waf_web_acl" "waf_acl" {
  name        = "${local.acl_id}_waf_acl"
  metric_name = "${local.metric_name}wafacl"
  default_action {
    type = "BLOCK"
  }
  rules {
    priority = 10
    rule_id  = aws_waf_rule.ip_whitelist.id
    action {
      type = "ALLOW"
    }
  }
  depends_on = [
    aws_waf_rule.ip_whitelist,
    aws_waf_ipset.ip_whitelist
  ]
}

resource "aws_waf_rule" "ip_whitelist" {
  name        = "${local. acl_id}_ip_whitelist_rule"
  metric_name = "${local.metric_name}ipwhitelist"
  depends_on = [aws_waf_ipset.ip_whitelist]
  predicates {
    data_id = aws_waf_ipset.ip_whitelist.id
    negated = false
    type    = "IPMatch"
  }
}

resource "aws_waf_ipset" "ip_whitelist" {
  name = "${local. acl_id}_match_ip_whitelist"
  dynamic "ip_set_descriptors" {
    for_each = toset(var.cidr_whitelist)
    content {
      type  = "IPV4"
      value = ip_set_descriptors.key
    }
  }
}

data "aws_route53_zone" "domain_name" {
  name         = var.hosted_zone
  private_zone = false
}

resource "aws_acm_certificate" "acm_cert" {
  domain_name   = var.acm_certificate_domain
  validation_method = "DNS"
  subject_alternative_names = ["*.${var.hosted_zone}"]
}

resource "aws_route53_record" "cert-validations" {
  count = 1
  zone_id = data.aws_route53_zone.domain_name.zone_id
  name    = element(aws_acm_certificate.acm_cert.domain_validation_options.*.resource_record_name, count.index)
  type    = element(aws_acm_certificate.acm_cert.domain_validation_options.*.resource_record_type, count.index)
  records = [element(aws_acm_certificate.acm_cert.domain_validation_options.*.resource_record_value, count.index)]
  ttl     = 60
}
data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    sid = "1"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::${var.domain_name}/*",
    ]
    principals {
      type = "AWS"
      identifiers = [
        aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn,
      ]
    }
  }
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = var.domain_name
  acl    = "private"
  versioning {
    enabled = true
  }
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "block_s3_access" {
  bucket = aws_s3_bucket.s3_bucket.id
  block_public_acls   = true
  block_public_policy = true
}

resource "aws_s3_bucket_object" "object" {
  for_each     = fileset("${path.module}/static_files", "*")
  bucket       = aws_s3_bucket.s3_bucket.bucket
  key          = each.value
  source       = "${path.module}/static_files/${each.value}"
  content_type = lookup(local.content_type_map, regex("\\.(?P<extension>[A-Za-z0-9]+)$", each.value).extension, "application/octet-stream")
  etag         = filemd5("${path.module}/static_files/${each.value}")
}


resource "aws_route53_record" "route53_record" {
  count = var.use_default_domain ? 0 : 1
  depends_on = [
    aws_cloudfront_distribution.s3_distribution
  ]

  zone_id = data.aws_route53_zone.domain_name.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name    = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [
    aws_s3_bucket.s3_bucket
  ]

  origin {
    domain_name = "${var.domain_name}.s3.amazonaws.com"
    origin_id   = "s3-cloudfront"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
  web_acl_id = aws_waf_web_acl.waf_acl.id
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = local.domain_name

  default_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD",
    ]

    cached_methods = [
      "GET",
      "HEAD",
    ]
    lambda_function_association {
      event_type = "viewer-request"
      lambda_arn = "${aws_lambda_function.lambda.qualified_arn}"
    }
    target_origin_id = "s3-cloudfront"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  price_class = var.price_class

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  dynamic "viewer_certificate" {
    for_each = local.default_certs
    content {
      cloudfront_default_certificate = true
    }
  }

  dynamic "viewer_certificate" {
    for_each = local.acm_certs
    content {
      acm_certificate_arn      = aws_acm_certificate.acm_cert.arn
      ssl_support_method       = "sni-only"
      minimum_protocol_version = "TLSv1"
    }
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    error_caching_min_ttl = 0
    response_page_path    = "/"
  }

  wait_for_deployment = false
  tags                = var.tags
}


output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "cloudfront_dist_id" {
  value = aws_cloudfront_distribution.s3_distribution.id
}

output "s3_domain_name" {
  value = aws_s3_bucket.s3_bucket.website_domain
}

output "website_address" {
  value = var.domain_name
}
