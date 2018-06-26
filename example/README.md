# Athena example

This example creates:
* an S3 bucket for storing S3 logs
* An Athena database and example queries for s3 logs
* An S3 bucket that is configured to log into the logging bucket, this bucket is also configured to host a static website, so that you can generate access logs by viewing the s3 website url in your browser.

The output of this terraform example is the S3 website url, and the url to Athena in the AWS console.