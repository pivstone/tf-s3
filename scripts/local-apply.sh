#! /bin/sh

export AWS_ENDPOINT_URL=http://localhost:4566/
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
cd teams/order

terraform fmt -recursive
terraform init
terraform apply

cd ../../