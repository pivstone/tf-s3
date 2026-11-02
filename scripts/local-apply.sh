#! /bin/sh

export AWS_ENDPOINT_URL=http://localhost:4566/
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export TF_BUCKET_NAME=tf-bucket

# setup
if lsof -Pi :4566 -sTCP:LISTEN -t >/dev/null ; then
    echo "minstack is running"
else
    (cd ./scripts && docker compose up -d)
fi

aws s3api wait bucket-not-exists --bucket $TF_BUCKET_NAME --no-cli-pager && aws s3api create-bucket --bucket $TF_BUCKET_NAME --region us-east-1 --no-cli-pager

# apply changes
terraform init  -reconfigure -backend-config "bucket=$TF_BUCKET_NAME"  -backend-config "key=team/order.tfstate"  -var-file teams/order/terraform.tfvars
terraform apply -var="attach_tls_only_policy=false" -var="attach_tls_12_required_policy=false" -auto-approve   -var-file teams/order/terraform.tfvars

# tear down
(cd ./scripts && docker compose down)
