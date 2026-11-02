# Terraform S3 Bucket Provision

## Prerequisites

- Terraform 1.16.0 or newer
- AWS CLI
- Docker

## Repository layout

```text
.github/
  actions/list-change/          # Detect changed team folders
  workflows/ci-teams.yaml       # Validate and plan changed teams
  workflows/ci-modules.yaml     # Run bucket module tests
  workflows/cd-teams.yaml       # Illustrative AWS deployment workflow
main.tf                        # Shared root: provider, backend, team role, and bucket modules
variables.tf                   # Shared team input contract
modules/aws/workload/bucket/
  main.tf                      # Bucket, bucket policy, and IAM permissions
  variables.tf                 # Module inputs and validation
  outputs.tf                   # Team name, bucket name, and ARN
  tests/                       # Naming checks and policy snapshots
  testing/                     # MiniStack setup and test fixture modules
teams/order/
  terraform.tfvars             # Team name and bucket declarations
scripts/                       # Local environment and helper scripts
```

## Design

### Team configuration

Teams declare their buckets in `teams/<team>/terraform.tfvars`:

```hcl
team_name = "order"

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
- Each team explicitly sets `team_name`; the shared root passes it to the bucket module.
- The IAM role is created outside the bucket loop, so each team has one role.
- The repository root manages one team per run, selected with `-var-file=teams/<team>/terraform.tfvars`.


### Naming Convention  

The module constructs bucket names using:

```text
<team>-<short-name>-<region>-<account-id>
```

Short names currently allow 4–32 lowercase letters, digits, and hyphens. Role names follow `<team>-s3-role`.


### State isolation

All teams use the shared Terraform root, but each team has a separate state object in an S3 backend bucket:

```text
s3://tf-bucket/teams/order.tfstate
s3://tf-bucket/teams/<another-team>.tfstate
```

The backend enables S3 state locking with `use_lockfile = true`. The backend bucket and team-specific key are supplied during `terraform init` using `-backend-config`; the team's resource inputs are supplied separately to `plan` and `apply` using `-var-file`.

> [!NOTE]
> The local demo stores state in MiniStack's S3 service. This demonstrates separate state keys without deploying to AWS. A production backend would require persistent storage and appropriate access controls.

Run commands from the repository root. When switching teams, reinitialize with the matching backend key before planning or applying that team's declaration. Changing only the variable file does not switch state.

## Local development

From the repository root:

```bash
docker compose -f scripts/docker-compose.yml up -d ministack

export AWS_ENDPOINT_URL=http://localhost:4566/
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
```

Wait for MiniStack to become healthy, then create the backend bucket once:

```bash
aws s3api create-bucket --bucket tf-bucket
```

Select a team and initialize its backend:

```bash
TEAM_NAME=order

terraform init -reconfigure \
  -backend-config="bucket=tf-bucket" \
  -backend-config="key=teams/${TEAM_NAME}.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="use_path_style=true"

terraform validate
terraform plan -input=false \
  -var-file="teams/${TEAM_NAME}/terraform.tfvars"
```

`terraform validate` checks configuration structure. `terraform plan` also evaluates the selected team's input values. Backend endpoint and path-style settings are described in the [Terraform S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3).

## Tests

The test suite includes mocked checks and a Docker-backed fixture using MiniStack to simulate AWS locally. Run the full suite from the repository root:

```bash
terraform -chdir=modules/aws/workload/bucket init
terraform -chdir=modules/aws/workload/bucket test
```

The fixture starts its own MiniStack container and requires port `4566` to be free, so stop the local demo container before running the full suite. Its assertions check a plan rather than applying bucket resources.

To run only naming and policy checks without starting MiniStack:

```bash
terraform -chdir=modules/aws/workload/bucket test \
  -filter=tests/bucket_name_validation.tftest.hcl \
  -filter=tests/bucket_policy_snapshots.tftest.hcl
```

Naming checks use a mocked AWS provider. Policy checks use resource and data overrides while retaining the provider's IAM policy JSON generation. These filtered tests do not provision AWS resources or require MiniStack. They use fixture inputs rather than the team declarations under `teams/`.

Policy tests compare decoded JSON against reviewed fixtures in `tests/snapshots/`. These checks verify policy structure, rather than AWS authorization behavior.


## CI/CD

- **Team CI:** The changed-folder action returns team names as a JSON array. Each matrix job runs from the shared repository root, starts MiniStack, creates a demo backend bucket, and is intended to validate and plan the selected team using `teams/<team>/terraform.tfvars` and state key `teams/<team>.tfstate`.
- **Module CI:** Changes to the bucket module trigger its Terraform test suite, including the Docker-backed fixture.
- **CD example:** The deployment workflow illustrates assuming an AWS role and applying each selected team using its own state key. The role ARN is a placeholder; real AWS deployment is outside this demonstration.

**TODO:** Align the workflow commands with the local example: `init` accepts backend configuration, `validate` does not accept variable files, and `plan`/`apply` accept `-var-file`. Add MiniStack readiness handling before backend initialization.

## Onboard a team

1. Create `teams/<new-team>/terraform.tfvars` using the valid example above.
2. Set `team_name` to match the folder name and declare at least one bucket with explicit visibility.
3. From the repository root, initialize with state key `teams/<new-team>.tfstate` and plan using the new team's variable file.
4. Open a pull request; the workflow selects the new team folder.

No shared root, bucket-module, or workflow edits are required to add a team. The EC2 trust policy currently comes from the shared root.

**TODO:** Explain CI batching and concurrency if many teams change in one pull request.

## Assumption

- Team roles currently trust EC2 through `sts:AssumeRole`; other workload identities would need a different trust policy.
- The team folder name, declared `team_name`, and backend key identify the same team. Their consistency is currently a convention rather than an enforced cross-check.
- Public buckets allow anonymous object reads through their bucket policy; private buckets omit that public read permission.
- HTTPS-only and minimum TLS 1.2 policies are enabled by default. The local HTTP integration helper disables them for its demo requests.
- Local helper scripts still contain commands for the previous per-folder root layout. Use the root-level commands documented above until those scripts are updated.
