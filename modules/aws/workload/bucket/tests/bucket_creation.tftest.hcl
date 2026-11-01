run "setup" {
  # Start the MiniStack

  module {
    source = "./testing/setup"
  }
}


run "execute" {
  module {
    source = "./testing/loader"
  }

  command = plan

  assert {
    condition     = length(module.buckets) == 2
    error_message = "The team should declare exactly two buckets."
  }

  assert {
    condition     = module.buckets.public.team_name == var.team_name && module.buckets.private.team_name == var.team_name
    error_message = "Both buckets must use the team identity supplied to the fixture."
  }

  assert {
    condition     = module.buckets.public.bucket_name == "${var.team_name}-public-bucket-${data.aws_region.current.region}-${data.aws_caller_identity.current.account_id}"
    error_message = "S3 Bucket name should follow the format"
  }

}


