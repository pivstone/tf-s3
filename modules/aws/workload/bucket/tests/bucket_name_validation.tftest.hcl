# Naming and input validation do not need real AWS policy generation.
mock_provider "aws" {
  override_during = plan

  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }

  mock_data "aws_caller_identity" {
    defaults = { account_id = "000000000" }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = jsonencode({ Version = "2012-10-17", Statement = [] })
    }
  }
}

variables {
  team_name = "order"
  name      = "assets"
  type      = "private"
  role_id   = "order-s3-role"
}

run "invalid_bucket_characters_are_rejected" {
  command = plan
  variables { name = "Bad_Name" }
  expect_failures = [var.name]
}

run "short_bucket_names_are_rejected" {
  command = plan
  variables { name = "abc" }
  expect_failures = [var.name]
}

run "long_bucket_names_are_rejected" {
  command = plan
  variables { name = "abcdefghijklmnopqrstuvwxyzabcdefg" }
  expect_failures = [var.name]
}

run "minimum_length_name_is_accepted" {
  command = plan
  variables { name = "abcd" }

  assert {
    condition     = output.bucket_name == "order-abcd-us-east-1-000000000"
    error_message = "A four-character short bucket name should be accepted."
  }
}

run "maximum_length_name_is_accepted" {
  command = plan
  variables { name = "abcdefghijklmnopqrstuvwxyzabcdef" }

  assert {
    condition     = output.bucket_name == "order-abcdefghijklmnopqrstuvwxyzabcdef-us-east-1-000000000"
    error_message = "A 32-character short bucket name should be accepted."
  }
}
