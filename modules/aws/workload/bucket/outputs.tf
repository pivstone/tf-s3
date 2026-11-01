output "team_name" {
  value       = local.team_name
  description = "Team Name"
}

output "bucket_name" {
  value       = local.bucket_name
  description = "S3 Bucket Full name"
}

output "arn" {
  value       = aws_s3_bucket.this.arn
  description = "S3 Bucket Arn"
}
