# Session 18 HW - Terraform & Infrastructure as Code

**Name:** Nanakjot Singh Chahal
**Enrollment No:** 24bcs10132

terraform v1.9.8 on ubuntu (wsl2).

> **note on AWS:** i do not have an AWS account with billing set up, so i did not run `terraform apply` against real AWS (that would create billable resources). instead i did it two ways:
> 1. the **AWS S3 config** - `init`, `fmt`, `validate` and a full `plan` using a provider block that skips credential calls, so i can see exactly what terraform *would* create without touching an account
> 2. a **local-provider config** (`local_file` + `random_pet`) where i ran the complete `init → plan → apply → state → destroy` cycle for real
>
> that way every terraform command in the session is demonstrated with real output.

---

## What is Infrastructure as Code

before IaC you created servers by clicking in a console or running commands by hand. problems: nobody knows exactly what is deployed, staging never matches production, and rebuilding after a failure is a manual guess.

IaC means the infrastructure is **code in git**: reviewable, repeatable, and versioned. terraform is **declarative** - i describe the end state i want and terraform figures out the API calls to get there.

```bash
terraform version
cat 01-iac-basics/main.tf
```

![Terraform version and first config](screenshots/Screenshot%202026-10-07%20173309.png)

the whole file is 4 blocks, and that is basically all of terraform:

| block | purpose |
|---|---|
| `terraform { required_providers }` | which providers and versions this config needs |
| `provider "aws" {}` | how to talk to the platform (region, credentials) |
| `resource "aws_s3_bucket" "iac_demo" {}` | the thing i actually want to exist |
| `output {}` | values to print after apply |

a resource address is `<type>.<name>` - so `aws_s3_bucket.iac_demo`. the type comes from the provider, the name is mine.

---

## fmt and validate (catching mistakes before apply)

```bash
terraform -chdir=terraform-s3-demo fmt -check -diff
terraform -chdir=terraform-s3-demo validate
```

![fmt and validate errors](screenshots/Screenshot%202026-10-07%20173314.png)

`fmt` passed (exit 0 = already formatted), but **`validate` found real errors** in the repo's `terraform-s3-demo/outputs.tf`:

```
Error: Unsupported argument
  on outputs.tf line 2, in output "bucket_name":
   2:   type        = string
An argument named "type" is not expected here.
```

an `output` block takes `value` and `description`, but **not** `type` - only `variable` blocks have a type. so this config could never have been applied.

### fixing it

```bash
cp -r terraform-s3-demo /tmp/tf-fixed && cd /tmp/tf-fixed
sed -i '/^  type  *= string$/d' outputs.tf
terraform validate
```

![validate success after fix](screenshots/Screenshot%202026-10-07%20173320.png)

after removing the three `type = string` lines it says **"Success! The configuration is valid."** (i did the fix on a copy in `/tmp` so i did not change the instructor's file).

this is exactly why `validate` exists - it is a free, offline syntax check you run before anything touches the cloud.

---

## terraform init

```bash
terraform init
```

![terraform init](screenshots/Screenshot%202026-10-07%20173541.png)

`init` reads `required_providers`, downloads the provider plugin (here **hashicorp/aws v6.67.0**), writes `.terraform.lock.hcl` to pin the exact version, and prepares the backend.

**a problem i hit:** the first init failed with `Error: Failed to install provider ... releases.hashicorp.com: net/http: TLS handshake timeout` - my connection kept dropping the ~100MB provider download. i fixed it by setting a plugin cache so the provider is downloaded once and reused:

```bash
export TF_PLUGIN_CACHE_DIR=$HOME/.terraform.d/plugin-cache
```

after that every `init` in any folder installs from the local cache instead of the internet.

---

## terraform plan

```bash
terraform fmt -check
terraform validate
terraform plan
```

![terraform plan](screenshots/Screenshot%202026-10-07%20173550.png)

`validate` says the config is valid and the plan shows exactly what would happen:

```
Terraform will perform the following actions:
  # aws_s3_bucket.iac_demo will be created
  + resource "aws_s3_bucket" "iac_demo" {
      + bucket_prefix = "session18-iac-"
      + force_destroy = true
      + region        = "ap-south-1"
      + arn           = (known after apply)
      + bucket        = (known after apply)
      ...
Plan: 1 to add, 0 to change, 0 to destroy.
```

two things worth noticing:

- **`(known after apply)`** means the value is decided by AWS, not by me - a bucket's ARN and final name do not exist until it is created. `bucket_prefix` lets AWS append a random suffix so the globally-unique bucket name cannot clash.
- **`Plan: 1 to add, 0 to change, 0 to destroy`** is the line to read in a code review. a plan showing unexpected `destroy` is how you catch a change that would wipe a database.

the provider block that makes this work offline:

```hcl
provider "aws" {
  region     = var.aws_region
  access_key = "mock-access-key"
  secret_key = "mock-secret-key"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}
```

without those skips the provider calls STS to check who i am and plan fails immediately. with them, terraform does all the config/graph work locally. `apply` would still need real credentials - which is the point: **plan is safe, apply is not.**

---

## The full cycle (local providers, really applied)

to actually run `apply`, `state` and `destroy` i used a config with only local providers - no cloud, no cost.

```bash
terraform init
terraform plan
```

![local demo init and plan](screenshots/Screenshot%202026-10-07%20173600.png)

```bash
terraform apply -auto-approve
cat generated/server-notes.txt
```

![terraform apply](screenshots/Screenshot%202026-10-07%20173607.png)

```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:
notes_file  = "./generated/server-notes.txt"
server_name = "stirred-dolphin"
```

and the file terraform created on disk:

```
Managed by Terraform
--------------------
server name : stirred-dolphin
environment : dev
student     : Nanakjot Singh Chahal
```

the interesting part is the **dependency**: `local_file` interpolates `${random_pet.server.id}`, so terraform knows it must create the random name *first*. i never declared that order - terraform built the dependency graph from the references.

### state and destroy

```bash
terraform state list
terraform state show random_pet.server
terraform output
terraform destroy -auto-approve
```

![state and destroy](screenshots/Screenshot%202026-10-07%20173616.png)

```
$ terraform state list
local_file.notes
random_pet.server

$ terraform destroy -auto-approve
Destroy complete! Resources: 2 destroyed.

$ terraform state list; ls generated
(both empty)
```

**state** is how terraform remembers what it created. `terraform.tfstate` maps my resource addresses to real IDs - that is how it knows `random_pet.server` already exists and has the id `stirred-dolphin`, so a second apply changes nothing instead of making another one.

that also means state is critical: lose it and terraform forgets it owns your infrastructure; commit it to git and you leak whatever secrets are in it. in a team it goes in a **remote backend** (S3 + DynamoDB lock, or terraform cloud) so everyone shares one state and two people cannot apply at once.

`destroy` reverses the graph - it deleted the file first, then the random name, and emptied the state.

---

## The commands in order

| command | what it does | safe to run? |
|---|---|---|
| `terraform init` | download providers, prepare the directory | yes |
| `terraform fmt` | reformat .tf files to the standard style | yes |
| `terraform validate` | check syntax and references, offline | yes |
| `terraform plan` | show what would change | yes (read only) |
| `terraform plan -out=tfplan` | save that exact plan | yes |
| `terraform apply tfplan` | make the changes | **no - changes real infra** |
| `terraform state list` / `show` | inspect what terraform tracks | yes |
| `terraform output` | print output values | yes |
| `terraform destroy` | delete everything in the state | **no - deletes real infra** |

---

## AWS services used in these labs

### EC2 (compute)
virtual machines. you pick an instance **family** by workload - `t`/`m` general purpose for web servers and k8s nodes, `c` compute optimised for CPU-heavy work, `r` memory optimised for in-memory databases, `g`/`p` with GPUs for ML. storage is **EBS** (network-attached block volumes, `gp3` for general use), and **Auto Scaling Groups** add/remove instances based on load.

### S3 (object storage)
not a filesystem - a flat **bucket** of **objects**, each with a key. bucket names are globally unique, which is why the lab uses `bucket_prefix` and lets AWS add a suffix. important features: **Block Public Access** (stops accidental public data), **pre-signed URLs** (temporary access without making the bucket public), **lifecycle rules** (move old data to Glacier or delete it), and **versioning**. it is the standard place for backups, static sites and data lakes.

### VPC (networking)
your own isolated network in AWS. the standard layout is **public subnets** (things that must be reachable - load balancers) and **private subnets** (app servers, databases). an **Internet Gateway** gives public subnets internet access; a **NAT Gateway** lets private subnets make *outbound* connections without being reachable from outside. **Route tables** decide where traffic goes, **security groups** are stateful per-instance firewalls, and **NACLs** are stateless subnet-level firewalls. this is the same public/private split i did with docker networks in session 8.

### IAM (identity and access)
controls who can do what. policies are JSON with **Effect** (Allow/Deny - an explicit Deny always wins), **Action** (`s3:GetObject`), **Resource** (an ARN) and optional **Condition**. the key practice is **roles instead of keys**: attach a role to the EC2 instance and the app gets temporary auto-rotating credentials, so no access keys are ever written in code. that is the same lesson as session 17's secret scanning.

### RDS / Aurora (relational database)
managed SQL (postgres, mysql, etc). AWS handles patching, backups and failover, so you do not run the database on an EC2 instance yourself. **Aurora** is AWS's own engine, wire-compatible with postgres/mysql, which replicates data across three availability zones. use it when you need **ACID transactions** and joins.

### DynamoDB (NoSQL)
serverless key-value/document store with single-digit millisecond reads. no joins - you model the table around your **access patterns**, using a **partition key** (which server holds the data) plus an optional **sort key** (order within the partition). good for very high throughput things like session stores, leaderboards and event metadata.

### how they fit together

```
            Internet
                │
        ┌───────▼────────┐  public subnet
        │  Load Balancer │
        └───────┬────────┘
                │
        ┌───────▼────────┐  private subnet
        │  EC2 / EKS     │──── IAM role ──► S3 (files)
        │  (the app)     │
        └───────┬────────┘
                │
        ┌───────▼────────┐  private subnet
        │  RDS / Dynamo  │
        └────────────────┘
       all inside one VPC, security groups between each tier
```

and every box in that diagram is something you would declare as a terraform `resource` instead of clicking in the console - which is what session 19 does with the VPC.
