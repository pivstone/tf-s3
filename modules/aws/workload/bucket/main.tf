terraform {
  required_version = ">=1.16.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  team_name = coalesce(var.team_name, basename(abspath(path.root)))
}

locals {
  bucket_name = "${local.team_name}-${var.name}-${data.aws_region.current.region}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name

  tags = merge(var.tags, {
    Team = local.team_name
  })
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.bucket
  block_public_acls       = var.type == "private"
  block_public_policy     = var.type == "private"
  ignore_public_acls      = var.type == "private"
  restrict_public_buckets = var.type == "private"
}

data "aws_iam_policy_document" "restrict_to_https_only" {
  statement {
    sid    = "RestrictToTLSRequestsOnly"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values = [
        "false"
      ]
    }
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]
  }
}

data "aws_iam_policy_document" "require_tls_12" {
  statement {
    sid    = "RequireTLS12"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*",
    ]

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values = [
        "1.2"
      ]
    }
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]
  }
}

data "aws_iam_policy_document" "public_read" {
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.this.arn}/*",
    ]
  }
}

data "aws_iam_policy_document" "combined" {
  source_policy_documents = [
    var.attach_tls_only_policy ? data.aws_iam_policy_document.restrict_to_https_only.json : "",
    var.attach_tls_12_required_policy ? data.aws_iam_policy_document.require_tls_12.json : "",
  var.type == "public" ? data.aws_iam_policy_document.public_read.json : ""]
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.bucket
  policy = data.aws_iam_policy_document.combined.json

}

data "aws_iam_policy_document" "s3_read_write_access" {
  statement {
    sid    = "ReadWriteAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject*",
      "s3:GetBucket*",
      "s3:List*",
      "s3:PutObject",
      "s3:PutObjectLegalHold",
      "s3:PutObjectRetention",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging",
      "s3:Abort*",
      "s3:DeleteObject*"
    ]

    resources = [
      "${aws_s3_bucket.this.arn}/*",
      "${aws_s3_bucket.this.arn}",
    ]
  }
  //todo: add deny for bucket deletion, bucket policy etc)
}

resource "aws_iam_role_policy" "role_policy" {
  role   = var.role_id
  policy = data.aws_iam_policy_document.s3_read_write_access.json
}
