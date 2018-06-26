variable "log_prefix" {
  description = "If the bucket has multiple S3 Bucket logs inside it, provide a prefix to select one"
  default     = ""
}

locals {
  # Strip starting and trailing slashes
  log_prefix_normalised = "${join("/",compact(split("/", var.log_prefix)))}"
}

variable "bucket_name" {
  description = "description"
  default     = "description"
}

module "label" {
  source     = "git::https://github.com/cloudposse/terraform-terraform-label.git?ref=tags/0.1.2"
  namespace  = "${var.namespace}"
  stage      = "${var.stage}"
  name       = "${var.name}"
  attributes = "${var.attributes}"
  delimiter  = "${var.delimiter}"
}

# Validate that the bucket exists by putting it in a data source
data "aws_s3_bucket" "default" {
  bucket = "${var.bucket_name}"
}

resource "aws_athena_database" "default" {
  name   = "${module.label.id}-db"
  bucket = "${data.aws_s3_bucket.default.id}"
}

resource "aws_athena_named_query" "create_table" {
  name     = "${module.label.id}-create-table"
  database = "${aws_athena_database.database.name}"

  query = <<QUERYTEXT
CREATE EXTERNAL TABLE IF NOT EXISTS s3_AccessLogs.Accesslogs(
BucketOwner string,
Bucket string,
RequestDateTime string,
RemoteIP string,
Requester string,
RequestID string,
Operation string,
Key string,
RequestURI_operation string,
RequestURI_key string,
RequestURI_httpProtoversion string,
HTTPstatus string,
ErrorCode string,
BytesSent string,
ObjectSize string,
TotalTime string,
TurnAroundTime string,
Referrer string,
UserAgent string,
VersionId string)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
WITH SERDEPROPERTIES (
'serialization.format' = '1',
'input.regex' = '([^ ]*) ([^ ]*) \\[(.*?)\\] ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) \\\"([^ ]*) ([^ ]*) (- |[^ ]*)\\\" (-|[0-9]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) (\"[^\"]*\") ([^ ]*)$'
) LOCATION 's3://${data.aws_s3_bucket.default.id}/${var.log_prefix}/'
QUERYTEXT

  lifecycle {
    ignore_changes = ["query"]
  }
}

resource "aws_athena_named_query" "requests_from_outside_vpc" {
  name        = "${module.label.id}-outside-vpc"
  database    = "${aws_athena_database.database.name}"
  description = "Select all requests that came from outside your VPC subnet - EXAMPLE"

  query = <<QUERYTEXT
/*
Query for access outside of AWS and your VPC
Replace 172.31% with your VPC CIDR
*/
SELECT Key,
        UserAgent,
        RemoteIp,
        count(*) AS cnt
FROM Accesslogs
WHERE regexp_like(RequestURI_operation, 'GET|HEAD')
        AND Requester LIKE '-'
        AND NOT regexp_like(UserAgent, 'Elastic|aws')
        AND RemoteIp NOT LIKE '172.31%'
GROUP BY  RemoteIp, Key, UserAgent, RemoteIp
ORDER BY cnt DESC LIMIT 10
QUERYTEXT

  lifecycle {
    ignore_changes = ["query"]
  }
}

resource "aws_athena_named_query" "requests_between_dates" {
  name        = "${module.label.id}-requests-between-dates"
  database    = "${aws_athena_database.database.name}"
  description = "Select all s3 requests between two dates - EXAMPLE"

  query = <<QUERYTEXT
SELECT Requester , Operation ,  RequestDateTime
FROM Accesslogs
WHERE Operation='REST.GET.OBJECT' AND
parse_datetime(RequestDateTime,'dd/MMM/yyyy:HH:mm:ss Z') 
BETWEEN parse_datetime('2016-12-05:16:56:36','yyyy-MM-dd:HH:mm:ss')
AND 
parse_datetime('2016-12-05:16:56:40','yyyy-MM-dd:HH:mm:ss');
QUERYTEXT

  lifecycle {
    ignore_changes = ["query"]
  }
}

resource "aws_athena_named_query" "requests_for_specific_path" {
  name        = "${module.label.id}-specific-s3-path"
  database    = "${aws_athena_database.database.name}"
  description = "Get distinct s3 paths which were accessed - EXAMPLE"

  query = <<QUERYTEXT
-- Get distinct s3paths which were accessed
SELECT DISTINCT(Key) 
FROM Accesslogs;
QUERYTEXT

  lifecycle {
    ignore_changes = ["query"]
  }
}

resource "aws_athena_named_query" "requests_since_date_path" {
  name        = "${module.label.id}-requests-since-date-s3-path"
  database    = "${aws_athena_database.database.name}"
  description = "Get access count for each s3 path after a given timestamp - EXAMPLE"

  query = <<QUERYTEXT
-- Get access count for each s3 path after a given timestamp
SELECT key, count(*) AS cnt 
FROM Accesslogs 
WHERE parse_datetime(RequestDateTime,'dd/MMM/yyyy:HH:mm:ss Z')  > parse_datetime('2016-12-05:16:56:40','yyyy-MM-dd:HH:mm:ss')
GROUP BY key
ORDER BY cnt DESC;
QUERYTEXT

  lifecycle {
    ignore_changes = ["query"]
  }
}

# Queries from http://aws.mannem.me/?p=1462

