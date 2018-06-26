### For connecting and provisioning
variable "region" {
  default = "us-east-1"
}

provider "aws" {
  region = "${var.region}"

  # Make it faster by skipping something
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}

# Create a s3 bucket for logging
module "log_storage" {
  source        = "git::https://github.com/cloudposse/terraform-aws-s3-log-storage.git?ref=master"
  name          = "logs"
  stage         = "prod"
  namespace     = "cp"
  force_destroy = "true"
}

# Generate the database and example queries.
module "athena" {
  source      = "../"
  namespace   = "cp"
  stage       = "prod"
  name        = "s3logquery"
  log_prefix  = "weblog/"
  bucket_name = "${module.log_storage.bucket_id}"
}

resource "aws_s3_bucket" "web" {
  bucket_prefix = "cp-prod-website-"
  acl           = "public-read"
  force_destroy = "true"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  logging {
    target_bucket = "${module.log_storage.bucket_id}"
    target_prefix = "weblog/"
  }
}

resource "aws_s3_bucket_policy" "b" {
  bucket = "${aws_s3_bucket.web.id}"

  policy = <<POLICY
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "PublicReadForGetTestBucketObjects",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.web.id}/*"
        }
    ]
}
POLICY
}

resource "aws_s3_bucket_object" "index" {
  bucket       = "${aws_s3_bucket.web.id}"
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"
  etag         = "${md5(file("${path.module}/index.html"))}"
}

resource "aws_s3_bucket_object" "error" {
  bucket       = "${aws_s3_bucket.web.id}"
  key          = "error.html"
  source       = "${path.module}/error.html"
  content_type = "text/html"
  etag         = "${md5(file("${path.module}/error.html"))}"
}

output "url" {
  value = "${aws_s3_bucket.web.website_endpoint}"
}

output "athena_console" {
  value = "https://console.aws.amazon.com/athena/saved-queries/home?region=us-east-1"
}
