########################
### Cloudtrail to S3 ###
########################

data "aws_iam_policy_document" "cloudtrail_to_s3" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [data.aws_s3_bucket.trail.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${data.aws_s3_bucket.trail.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_to_s3" {
  count  = var.org_cloudtrail_enabled ? 1 : 0
  bucket = data.aws_s3_bucket.trail.id
  policy = data.aws_iam_policy_document.cloudtrail_to_s3.json
}

################################
### Cloudtrail to Cloudwatch ###
################################

data "aws_iam_policy_document" "cloudtrail_to_cloudwatch_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudtrail_to_cloudwatch" {
  count              = var.org_cloudtrail_enabled ? 1 : 0
  name               = "cloudtrail-to-cloudwatch"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_to_cloudwatch_assume_role_policy.json
}


resource "aws_iam_policy" "cloudtrail_to_cloudwatch_policy" {
  count = var.org_cloudtrail_enabled ? 1 : 0
  name  = "Cloudtrail_to_Cloudwatch_Create_Put"

  policy = jsonencode({

    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AWSCloudTrailCreateLogStream",
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogStream"
        ],
        "Resource" : [
          "${aws_cloudwatch_log_group.cloudtrail_1day[0].arn}:*"
        ]
      },
      {
        "Sid" : "AWSCloudTrailPutLogEvents",
        "Effect" : "Allow",
        "Action" : [
          "logs:PutLogEvents"
        ],
        "Resource" : [
          "${aws_cloudwatch_log_group.cloudtrail_1day[0].arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudtrail_to_cloudwatch_attachment" {
  count      = var.org_cloudtrail_enabled ? 1 : 0
  role       = aws_iam_role.cloudtrail_to_cloudwatch[0].name
  policy_arn = aws_iam_policy.cloudtrail_to_cloudwatch_policy[0].arn
}