# Devops Assessment
## About
Automate deployment of a protected static web app. The source code for the web app is
available at https://github.com/PlanitarInc/secret-app. Write a terraform config to deploy the
web app according to the requirements below and provide a quick design of your solution in
the readme file of your Git repository.

### Application password:
Username: admin
Password: admin
Type: Basic Auth

### Requirments:
- AWS account and IAM Admin role.
- Lambda Edge funtion
- S3
- Cloudfront
- Web application firewall
- Iam policies
- ACM
- terraform 0.12+

### Terraform Script:
**TF Variables:**
hosted_zone="Name of the DNS Hosted zone"
domain_name="test-cdn-app-001.example.com"
acm_certificate_domain = "example.com"
tags={app="test"}
name="edge_lambda002"
archive_path="index.zip"
handler_name="index.handler"
cidr_whitelist = [
  "3.3.3.3/32",
  "2.2.2.2/32",
  "1.1.1.1/32",
  ]

How to run --
Modify the cidr_whitelist var accordingly, Else webpage wont be accessible.
```sh
terraform init
terraform plan
terraform apply
```

