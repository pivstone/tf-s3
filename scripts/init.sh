#! /bin/sh

export AWS_ENDPOINT_URL=http://localhost:4566/
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export TF_BUCKET_NAME=tf-bucket

aws s3api wait bucket-not-exists --bucket $AWS_DEFAULT_REGION --no-cli-pager && aws s3api create-bucket --bucket $TF_BUCKET_NAME --region us-east-1 --no-cli-pager

terraform init  -reconfigure -backend-config "bucket=tf-bucket"  -backend-config "key=team/order.tfstate"  -var-file teams/order/terraform.tfvars

terraform apply  -var-file teams/order/terraform.tfvars