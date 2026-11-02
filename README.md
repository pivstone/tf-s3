# Terraform S3 Bucket Provisioning

A shared Terraform configuration for provisioning one IAM role and one or more S3 buckets per team. Teams own their resource declarations, while the shared module defines naming, access policies, and ownership tags. MiniStack provides the local AWS simulation for development and testing.

## Prerequisites

- Terraform 1.16.0 or newer
- AWS CLI
- Docker with a running daemon

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
    tags = {
      Purpose = "Public assets"
    }
  },
  {
    name = "private-data"
    type = "private"
    tags = {
      Purpose = "Application data"
    }
  }
]
```

- At least one bucket is required.
- Each bucket must explicitly declare `public` or `private`; there is no visibility default.
- Each bucket declaration must include a `tags` map; use `{}` when no additional tags are needed.
- Bucket short names must be unique within a team because they are used as `for_each` keys.
- Each team explicitly sets `team_name`; the shared root passes it to the bucket module.
- The IAM role is created outside the bucket loop, so each team has one role.
- The repository root manages one team per run, selected with `-var-file=teams/<team>/terraform.tfvars`.

The module merges each bucket's custom tags with its required `Team` tag. The module's team identity takes precedence if a custom `Team` tag is supplied.

### Naming convention

The module constructs bucket names using:

```text
<team>-<short-name>-<region>-<account-id>
```

Short names currently allow 4–32 lowercase letters, digits, and hyphens. Role names follow `<team>-s3-role`. The current input validation checks the short name; the complete generated name must also meet S3 naming limits.

### State isolation

All teams use the shared Terraform root, but each team has a separate state object in an S3 backend bucket:

```text
s3://tf-bucket/teams/order.tfstate
s3://tf-bucket/teams/<another-team>.tfstate
```

The backend enables S3 state locking with `use_lockfile = true`. The backend bucket and team-specific key are supplied during `terraform init` using `-backend-config`; the team's resource inputs are supplied separately to `plan` and `apply` using `-var-file`.

> [!NOTE]
> The local demo stores state in MiniStack's S3 service. This demonstrates separate state keys without deploying to AWS. A production backend would require persistent storage and appropriate access controls.

The demo's Docker Compose configuration does not mount persistent storage. Removing the MiniStack container also removes its local resources and backend state.

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

After initializing the module, run only naming and policy checks without starting MiniStack:

```bash
terraform -chdir=modules/aws/workload/bucket test \
  -filter=tests/bucket_name_validation.tftest.hcl \
  -filter=tests/bucket_policy_snapshots.tftest.hcl
```

Naming checks use a mocked AWS provider. Policy checks use resource and data overrides while retaining the provider's IAM policy JSON generation. These filtered tests do not provision AWS resources or require MiniStack. They use fixture inputs rather than the team declarations under `teams/`.

Policy tests compare decoded JSON against reviewed fixtures in `tests/snapshots/`. These checks verify policy structure, rather than AWS authorization behavior.

### Integration test concept

`scripts/integration-test.sh` illustrates an end-to-end check of public and private bucket access. It applies the example team's resources against MiniStack, uploads a test object to each bucket, and checks that anonymous requests return HTTP `200` for the public object and `403` for the private object.

The helper disables the HTTPS-only and minimum TLS policies for its local HTTP requests. It uses fixed example bucket names and the state key `team/order.tfstate`, while the commands above use `teams/order.tfstate`. Align the keys before using both approaches with the same infrastructure. This helper is separate from the Terraform fixture test, which checks a plan.

## CI/CD

- **Team CI:** The changed-folder action returns team names as a JSON array. Each matrix job runs from the shared repository root, starts MiniStack, creates a demo backend bucket, and is intended to validate and plan the selected team using `teams/<team>/terraform.tfvars` and state key `teams/<team>.tfstate`.
- **Module CI:** Changes to the bucket module trigger its Terraform test suite, including the Docker-backed fixture.
- **CD example:** The deployment workflow illustrates assuming an AWS role and applying each selected team using its own state key. The role ARN is a placeholder; real AWS deployment is outside this demonstration.

The team workflow's backend bucket is created inside its temporary MiniStack container, so it does not preserve deployment state between workflow runs. MiniStack readiness handling and checks for an empty changed-team matrix remain implementation improvements.

## Onboarding a team

1. Create `teams/<new-team>/terraform.tfvars` using the valid example above.
2. Set `team_name` to match the folder name and declare at least one bucket with explicit visibility and a `tags` map.
3. From the repository root, initialize with state key `teams/<new-team>.tfstate` and plan using the new team's variable file.
4. Open a pull request; the workflow selects the new team folder.

No shared root, bucket-module, or workflow edits are required to add a team. The EC2 trust policy currently comes from the shared root.

## Offboarding a team

S3 requires a bucket to be empty before it can be deleted. Offboarding is a manual process in this demonstration; deleting the team's declaration file does not destroy its resources.

1. Stop applications and other writers using the team's buckets. Confirm whether the data should be retained, archived, or deleted.
2. While the team's declaration file is still available, initialize Terraform with the same backend bucket and state key used to provision that team.
3. Archive or remove the bucket contents as agreed. If versioning has been enabled outside this module, include object versions and delete markers when emptying the buckets.
4. Run `terraform plan -destroy -var-file="teams/<team>/terraform.tfvars"` and review the resources selected for deletion.
5. Run `terraform destroy -var-file="teams/<team>/terraform.tfvars"` and confirm that the team's managed resources have been removed.
6. Remove the team's declaration file from Git after cleanup succeeds. Retain state and audit records according to the organization's retention policy.

The shared backend bucket is created separately and is not part of a team's managed resources. Resources created outside this Terraform configuration require separate cleanup.

## Assumptions

- All teams use the same shared module and platform policy defaults. Bucket names, visibility, and custom tags are declared per team.
- The demo targets one AWS account and the `us-east-1` region. Separate environment configurations are not implemented.
- Each team needs one role with S3 read/write access, including object deletion. Separate read-only roles are outside the scope of this example.
- Team roles currently trust EC2 through `sts:AssumeRole`; other workload identities would need a different trust policy.
- The team folder name, declared `team_name`, and backend key identify the same team. Their consistency is currently a convention rather than an enforced cross-check.
- Public buckets allow anonymous object reads through their bucket policy; private buckets omit that public read permission.
- HTTPS-only and minimum TLS 1.2 policies are enabled by default. The local HTTP integration helper disables them for its demo requests.
- Team isolation depends on selecting the matching backend key and variable file for each run; separate declaration folders alone do not select a different state.

## Notice

- MiniStack does not enforce IAM policies by default. The Docker Compose setup enables `AUTH=true` to exercise access-policy behavior. The Terraform test fixture and team CI container do not currently enable this setting.
- The local example uses an HTTP endpoint. For demo requests over HTTP, set `attach_tls_only_policy=false` and `attach_tls_12_required_policy=false`; otherwise, the transport policies can deny those requests. Keep the policies enabled for AWS deployments.
- Team CI uses MiniStack for its demo S3 backend. The CD workflow is an illustrative AWS deployment with a placeholder role ARN. A production deployment would require its own persistent backend and authentication configuration.

## Security and compliance

- **Encryption:** The module does not explicitly configure server-side encryption or customer-managed KMS keys. AWS automatically encrypts new S3 uploads with SSE-S3. Customer-managed KMS support and the associated permissions would need to be added if required. See the [S3 encryption documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-bucket-encryption.html).
- **Versioning:** The module does not enable S3 bucket versioning.
- **Bucket deletion permissions:** The team role's policy does not grant `s3:DeleteBucket`. The Terraform deployment identity is separate and needs the permissions required to manage the infrastructure.
- **Deletion protection:** The module does not configure explicit retention or deletion protection. S3 rejects deletion of a nonempty bucket, but Terraform can still delete an empty bucket. An empty bucket is not necessarily unused; retention and deletion decisions should be reviewed during offboarding. In CloudFormation, resource retention is configured with [`DeletionPolicy: Retain`](https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-attribute-deletionpolicy.html).

## AI usage

AI assistance was used for:

- Documentation drafting, updates, and polishing.
- Troubleshooting Terraform errors and local development issues.
- Code review.
- Test scaffolding and bucket-policy snapshot tests.
- Workflow commands and changed-team detection.
