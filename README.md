# Terraform S3 Bucket Provision

## Prerequisites
- Terraform
- AWS CLI
- Docker

## Repository layout

```text
.github/
  actions/list-change/          # Detect changed team folders
  workflows/ci-teams.yaml       # Validate and plan changed teams
  workflows/ci-modules.yaml     # Run bucket module tests
  workflows/cd-teams.yaml       # Illustrative AWS deployment workflow
modules/aws/workload/bucket/
  main.tf                      # Bucket, bucket policy, and IAM permissions
  variables.tf                 # Module inputs and validation
  outputs.tf                   # Team name, bucket name, and ARN
  tests/                       # Naming checks and policy snapshots
  testing/                     # MiniStack setup and test fixture modules
teams/order/
  main.tf                      # Team role and bucket module instances
  variables.tf                 # Team input contract
  terraform.tfvars             # Team bucket declarations
scripts/                       # Local environment and helper scripts
```

## Design

### Team configuration

Teams declare their buckets in `teams/<team>/terraform.tfvars`:

```hcl
buckets = [
  {
    name = "public-assets"
    type = "public"
  },
  {
    name = "private-data"
    type = "private"
  }
]
```

- At least one bucket is required.
- Each bucket must explicitly declare `public` or `private`; there is no visibility default.
- Bucket short names must be unique within a team because they are used as `for_each` keys.
- The team name is derived from its root folder name.
- The IAM role is created outside the bucket loop, so each team has one role.


### Naming Convention  

The module constructs bucket names using:

```text
<team>-<short-name>-<region>-<account-id>
```

Short names currently allow 4–32 lowercase letters, digits, and hyphens. Role names follow `<team>-s3-role`.


### State isolation

Each `teams/<team>/` directory is an independent Terraform root. 
>> [!Notice]
>> This codebase is using local backend as an easily setup for demo purpose. There is a simple S3 bucket as remote backend in the commented code block. The production backend should be setup accordingly

Run team commands from the corresponding directory, or use `terraform -chdir=teams/<team>`.

## Local development

From the repository root:

```bash
docker compose -f scripts/docker-compose.yml up -d ministack

export AWS_ENDPOINT_URL=http://localhost:4566/
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

cd teams/order
terraform init
terraform validate
terraform plan -input=false
```

## Tests
The test suit includes mock and integration test. In this project, it's using Ministack to provide a local AWS stacks.

```bash
cd modules/aws/workload/bucket
terraform init
terraform test
```

Naming checks use a mocked AWS provider. Policy checks use resource and data overrides while retaining the provider's IAM policy JSON generation. These filtered tests do not provision AWS resources or require MiniStack.

Policy tests compare decoded JSON against reviewed fixtures in `tests/snapshots/`. These checks verify policy structure, rather than AWS authorization behavior.


## CI/CD


## Onboard a team

1. Copy the example root into `teams/<new-team>/`
2. Set the team's bucket declarations and review its role trust policy.
3. Run the local checks from that root.
4. Open a pull request; the workflow selects the new team folder.

No shared bucket-module edits are required.

**TODO:** Explain what is copied today and how you would reduce repetition if the platform grew to 300+ teams.

## Assumption
- IAM Role Assumption
