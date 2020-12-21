hosted_zone="example.com"
domain_name="test-cdn-app-001.example.com"
acm_certificate_domain = "example.com"
tags={app="test"}
name="edge_lambda_auth"
archive_path="index.zip"
handler_name="index.handler"
cidr_whitelist = [
  "2.2.2.2/32",
  "2.2.2.2/32",
  "1.1.1.1/32",
]
