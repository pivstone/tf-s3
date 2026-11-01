#! /bin/sh

export AWS_ENDPOINT_URL=http://localhost:4566/
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# setup
(cd ./scripts && docker compose up -d)

# apply tf changes
cd teams/order

terraform init
terraform apply -var="attach_tls_only_policy=false" -var="attach_tls_12_required_policy=false" -auto-approve 

cd ../../

# upload test file
aws s3 cp ./scripts/GitHub-logo.png s3://order-private-file-us-east-1-000000000000 --endpoint-url=http://localhost:4566
aws s3 cp ./scripts/GitHub-logo.png s3://order-public-file-us-east-1-000000000000 --endpoint-url=http://localhost:4566

# assertion
private_file_code=$(curl -o /dev/null -s -w "%{http_code}\n" http://localhost:4566/order-private-file-us-east-1-000000000000/GitHub-logo.png)
public_file_code=$(curl -o /dev/null -s -w "%{http_code}\n" http://localhost:4566/order-public-file-us-east-1-000000000000/GitHub-logo.png)

if [[ $private_file_code != 403 ]] ; then
    echo "Private Bucket Policy Test Failed"
    exit -1
fi

if [[ $public_file_code != 200 ]] ; then
    echo "Public Bucket Policy Test Failed"
    exit -1
fi

# tear down
(cd ./scripts && docker compose down)
