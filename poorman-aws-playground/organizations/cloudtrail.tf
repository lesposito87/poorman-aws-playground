locals {
  trail_name      = var.account_name
  trail_s3_bucket = var.org_s3_bucket
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_s3_bucket" "trail" {
  bucket = local.trail_s3_bucket
}

resource "aws_cloudtrail" "trail" {
  count                         = var.org_cloudtrail_enabled ? 1 : 0
  name                          = local.trail_name
  s3_bucket_name                = data.aws_s3_bucket.trail.id
  include_global_service_events = true
  is_organization_trail         = true
  is_multi_region_trail         = true # Needed to log GlobalService actions like IAM
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail_1day[0].arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_to_cloudwatch[0].arn

  advanced_event_selector {
    name = "LogManagementWriteEventsOnly"
    
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]  # Only management events
    }
    field_selector {
      field  = "readOnly"
      equals = ["false"]  # 'false' means only write operations will be logged (creation, deletion, etc.)
    }
  }
}

resource "aws_cloudwatch_log_group" "cloudtrail_1day" {
  count             = var.org_cloudtrail_enabled ? 1 : 0
  name              = "cloudtrail-1day"
  retention_in_days = 1
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = data.aws_s3_bucket.trail.id

  rule {
    id = "expireAWSLogs7d"

    filter {
      prefix = "AWSLogs/"
    }
    expiration {
      days = 7
    }

    status = "Enabled"
  }
}