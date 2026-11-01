terraform {
  required_version = ">=1.16.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # 
  # backend "s3" {
  #   bucket = "tf-bucket"
  #   key    = "team/order"
  #   region = "us-east-1"
  # }
}

# Configure the AWS Provider

provider "aws" {
  region = "us-east-1"
}

locals {
  team_name = basename(abspath(path.root))
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "role" {
  name               = "${local.team_name}-s3-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

module "buckets" {
  source = "../../modules/aws/workload/bucket"
  for_each = {
    for index, bucket in var.buckets :
    bucket.name => bucket
  }
  name                          = each.value.name
  type                          = each.value.type
  attach_tls_only_policy        = var.attach_tls_only_policy
  attach_tls_12_required_policy = var.attach_tls_12_required_policy
  role_id                       = aws_iam_role.role.id
}
