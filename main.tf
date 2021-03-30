module "label" {
  source     = "git::https://github.com/cloudposse/terraform-terraform-label.git?ref=tags/0.4.0"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  attributes = var.attributes
  delimiter  = "_"
}

module "label_table" {
  source     = "git::https://github.com/cloudposse/terraform-terraform-label.git?ref=tags/0.4.0"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  attributes = ["table"]
  delimiter  = "_"
}

# Validate that the bucket exists by putting it in a data source
data "aws_s3_bucket" "default" {
  bucket = var.bucket_name
}

resource "aws_athena_database" "database" {
  name   = "${module.label.id}_db"
  bucket = data.aws_s3_bucket.default.id
}

resource "aws_athena_named_query" "create_table" {
  name        = "${module.label.id}_create_table"
  database    = aws_athena_database.database.name
  description = "Create the S3 logs query table"

  query = <<QUERYTEXT
CREATE EXTERNAL TABLE IF NOT EXISTS ${aws_athena_database.database.name}.${module.label_table.id} (
            type string,
            time string,
            elb string,
            client_ip string,
            client_port int,
            target_ip string,
            target_port int,
            request_processing_time double,
            target_processing_time double,
            response_processing_time double,
            elb_status_code string,
            target_status_code string,
            received_bytes bigint,
            sent_bytes bigint,
            request_verb string,
            request_url string,
            request_proto string,
            user_agent string,
            ssl_cipher string,
            ssl_protocol string,
            target_group_arn string,
            trace_id string,
            domain_name string,
            chosen_cert_arn string,
            matched_rule_priority string,
            request_creation_time string,
            actions_executed string,
            redirect_url string,
            lambda_error_reason string,
            target_port_list string,
            target_status_code_list string,
            classification string,
            classification_reason string
            )
            ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
            WITH SERDEPROPERTIES (
            'serialization.format' = '1',
            'input.regex' = 
        '([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*):([0-9]*) ([^ ]*)[:-]([0-9]*) ([-.0-9]*) ([-.0-9]*) ([-.0-9]*) (|[-0-9]*) (-|[-0-9]*) ([-0-9]*) ([-0-9]*) \"([^ ]*) ([^ ]*) (- |[^ ]*)\" \"([^\"]*)\" ([A-Z0-9-]+) ([A-Za-z0-9.-]*) ([^ ]*) \"([^\"]*)\" \"([^\"]*)\" \"([^\"]*)\" ([-.0-9]*) ([^ ]*) \"([^\"]*)\" \"([^\"]*)\" \"([^ ]*)\" \"([^\s]+?)\" \"([^\s]+)\" \"([^ ]*)\" \"([^ ]*)\"')
            LOCATION 's3://${data.aws_s3_bucket.default.id}/${local.log_prefix_normalised}/'
            TBLPROPERTIES ('has_encrypted_data'='${var.bucket_encrypted_with_kms}');
QUERYTEXT
}

resource "aws_athena_named_query" "logs_from_time" {
  name        = "${module.label.id}_requests_since_date_s3_path"
  database    = aws_athena_database.database.name
  description = "Get logs for a timestamp - EXAMPLE"
  depends_on  = [aws_athena_named_query.create_table]

  query = <<QUERYTEXT
-- Get logs for given timestamp
SELECT * 
FROM ${module.label_table.id}
WHERE time like '2021-03-30T08:2%'
limit 20;
QUERYTEXT

}

# Queries from http://aws.mannem.me/?p=1462
