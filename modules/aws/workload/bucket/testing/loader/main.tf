variable "team_name" {
  description = "Team Name for test fixture."
  type        = string
  default     = "test"
  nullable    = false
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  endpoints {
    iam = "http://localhost:4566"
    s3  = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
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
  name               = "${var.team_name}-s3-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

module "buckets" {
  source = "../../"
  for_each = {
    public : {
      name : "public-bucket"
      type : "public"
    }

    private : {
      name : "private-bucket"
      type : "private"
    }
  }
  team_name = var.team_name
  name      = each.value.name
  type      = each.value.type
  role_id   = aws_iam_role.role.id
}

