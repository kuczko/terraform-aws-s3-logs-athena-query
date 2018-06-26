module "label" {
  source     = "git::https://github.com/cloudposse/terraform-terraform-label.git?ref=tags/0.1.2"
  namespace  = "${var.namespace}"
  stage      = "${var.stage}"
  name       = "${var.name}"
  attributes = "${var.attributes}"
  delimiter  = "_"
}

module "label_table" {
  source     = "git::https://github.com/cloudposse/terraform-terraform-label.git?ref=tags/0.1.2"
  namespace  = "${var.namespace}"
  stage      = "${var.stage}"
  name       = "${var.name}"
  attributes = ["table"]
  delimiter  = "_"
}

# Validate that the bucket exists by putting it in a data source
data "aws_s3_bucket" "default" {
  bucket = "${var.bucket_name}"
}

resource "aws_athena_database" "database" {
  name   = "${module.label.id}_db"
  bucket = "${data.aws_s3_bucket.default.id}"
}

resource "aws_athena_named_query" "create_table" {
  name        = "${module.label.id}_create_table"
  database    = "${aws_athena_database.database.name}"
  description = "Create the S3 logs query table"

  query = <<QUERYTEXT
CREATE EXTERNAL TABLE IF NOT EXISTS ${aws_athena_database.database.name}.${module.label_table.id}(
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
'input.regex' = '([^ ]*) ([^ ]*) \\[(.*?)\\] ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) \\\"([^ ]*) ([^ ]*) (- |[^ ]*)\\\" (-|[0-9]*) (-|[0-9]*) ([-0-9]*) ([-0-9]*) ([-0-9]*) ([-0-9]*) ([^ ]*) (\"[^\"]*\") ([^ ]*)$'
) LOCATION 's3://${data.aws_s3_bucket.default.id}/${local.log_prefix_normalised}/'
TBLPROPERTIES ('has_encrypted_data'='${var.bucket_encrypted_with_kms}');
QUERYTEXT
}

resource "aws_athena_named_query" "requests_from_outside_vpc" {
  name        = "${module.label.id}_outside_vpc"
  database    = "${aws_athena_database.database.name}"
  description = "Select all requests that came from outside your VPC subnet - EXAMPLE"
  depends_on  = ["aws_athena_named_query.create_table"]

  query = <<QUERYTEXT
/*
Query for access outside of AWS and your VPC
Replace 172.31% with your VPC CIDR
*/
SELECT Key,
        UserAgent,
        RemoteIp,
        count(*) AS cnt
FROM ${module.label_table.id}
WHERE regexp_like(RequestURI_operation, 'GET|HEAD')
        AND Requester LIKE '-'
        AND NOT regexp_like(UserAgent, 'Elastic|aws')
        AND RemoteIp NOT LIKE '172.31%'
GROUP BY  RemoteIp, Key, UserAgent, RemoteIp
ORDER BY cnt DESC LIMIT 10
QUERYTEXT
}

resource "aws_athena_named_query" "requests_between_dates" {
  name        = "${module.label.id}_requests_between_dates"
  database    = "${aws_athena_database.database.name}"
  description = "Select all s3 requests between two dates - EXAMPLE"
  depends_on  = ["aws_athena_named_query.create_table"]

  query = <<QUERYTEXT
SELECT Requester , Operation ,  RequestDateTime
FROM ${module.label_table.id}
WHERE Operation='REST.GET.OBJECT' AND
parse_datetime(RequestDateTime,'dd/MMM/yyyy:HH:mm:ss Z') 
BETWEEN parse_datetime('2016-12-05:16:56:36','yyyy-MM-dd:HH:mm:ss')
AND 
parse_datetime('2020-12-05:16:56:40','yyyy-MM-dd:HH:mm:ss');
QUERYTEXT
}

resource "aws_athena_named_query" "requests_for_specific_path" {
  name        = "${module.label.id}_specific_s3_path"
  database    = "${aws_athena_database.database.name}"
  description = "Get distinct s3 paths which were accessed - EXAMPLE"
  depends_on  = ["aws_athena_named_query.create_table"]

  query = <<QUERYTEXT
-- Get distinct s3paths which were accessed
SELECT DISTINCT(Key) 
FROM ${module.label_table.id};
QUERYTEXT
}

resource "aws_athena_named_query" "requests_since_date_path" {
  name        = "${module.label.id}_requests_since_date_s3_path"
  database    = "${aws_athena_database.database.name}"
  description = "Get access count for each s3 path after a given timestamp - EXAMPLE"
  depends_on  = ["aws_athena_named_query.create_table"]

  query = <<QUERYTEXT
-- Get access count for each s3 path after a given timestamp
SELECT key, count(*) AS cnt 
FROM ${module.label_table.id} 
WHERE parse_datetime(RequestDateTime,'dd/MMM/yyyy:HH:mm:ss Z')  > parse_datetime('2018-01-05:16:56:40','yyyy-MM-dd:HH:mm:ss')
GROUP BY key
ORDER BY cnt DESC;
QUERYTEXT
}

# Queries from http://aws.mannem.me/?p=1462

