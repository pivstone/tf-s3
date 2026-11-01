provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    iam = "http://localhost:4566"
    s3  = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}

variables {
  team_name = "order"
  name      = "assets"
  type      = "private"
  role_id   = "order-s3-role"
}

override_data {
  target = data.aws_region.current
  values = { region = "us-east-1" }
}

override_data {
  target = data.aws_caller_identity.current
  values = { account_id = "00000000000" }
}

override_resource {
  target = aws_s3_bucket.this
  values = {
    arn = "arn:aws:s3:::order-assets-us-east-1-00000000000"
  }
}

override_resource {
  target = aws_s3_bucket_public_access_block.this
}

override_resource {
  target = aws_s3_bucket_policy.this
}

override_resource {
  target = aws_iam_role_policy.role_policy
}

run "private_bucket_policy" {
  command = apply

  assert {
    condition = jsondecode(aws_s3_bucket_policy.this.policy) == jsondecode(
      file("${path.module}/tests/snapshots/private.json")
    )
    error_message = "Private bucket policy differs from its reviewed JSON snapshot."
  }
}

run "public_bucket_policy" {
  command = apply
  variables { type = "public" }

  assert {
    condition = jsondecode(aws_s3_bucket_policy.this.policy) == jsondecode(
      file("${path.module}/tests/snapshots/public.json")
    )
    error_message = "Public bucket policy differs from its reviewed JSON snapshot."
  }
}

