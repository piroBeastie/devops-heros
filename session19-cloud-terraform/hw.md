# Session 19 HW - Cloud Concepts & Terraform VPC

**Name:** Nanakjot Singh Chahal
**Enrollment No:** 24bcs10132

> same approach as session 18: i have no AWS account with billing, so i did **not** run `apply` (a VPC with an internet gateway is free, but i am not going to create resources in an account i do not have). i ran `init`, `fmt`, `validate`, `plan` and `show` against a copy of the lab config with a provider that skips credential calls, so the plan output is real and shows exactly what would be created.

---

## 1. Cloud service models

| model | what you manage | what the provider manages | example |
|---|---|---|---|
| **IaaS** | OS, runtime, app, data | hardware, network, virtualisation | EC2, VPC, EBS |
| **PaaS** | app and data only | OS, runtime, scaling, patching | RDS, Elastic Beanstalk, App Runner |
| **SaaS** | just your data/settings | everything | Gmail, GitHub, Datadog |

the trade-off is control vs effort. EC2 gives full control but i patch the OS myself; RDS takes that away but also takes away the 3am OS patching. kubernetes is interesting here - EKS is the control plane as PaaS while the worker nodes are still IaaS.

## 2. Regions and Availability Zones

- a **region** is a geographic location (`ap-south-1` = Mumbai). you pick it for **latency** to users, **data residency** laws, and **price** (regions cost different amounts).
- an **AZ** is one or more physically separate datacenters inside a region (`ap-south-1a`, `1b`, `1c`), with independent power and cooling but low-latency links between them.

the rule: **spread across AZs for high availability, spread across regions for disaster recovery.** if a subnet lives in a single AZ and that AZ fails, everything in it goes down - so production runs subnets in at least 2 AZs behind a load balancer.

the lab config uses `ap-south-1` and one public subnet, which is fine for learning but is a single point of failure.

---

## 3. The VPC config

```bash
grep -vE '^\s*#|^\s*$' main.tf
```

![VPC config](screenshots/Screenshot%202026-10-07%20173949.png)

six resources that together make a working public network:

| resource | what it does | value in the lab |
|---|---|---|
| `aws_vpc.main` | the private network itself | `10.0.0.0/16` (65k addresses) |
| `aws_subnet.public` | a slice of the VPC in one AZ | `10.0.1.0/24` (256 addresses) |
| `aws_internet_gateway.main` | attaches the VPC to the internet | - |
| `aws_route_table.public` | where traffic goes | `0.0.0.0/0` → the IGW |
| `aws_route_table_association.public` | links the route table to the subnet | - |
| `aws_security_group.web` | per-instance firewall | in: 80, 443 / out: all |

**what makes a subnet "public" is not a setting called public** - it is the fact that its route table has a `0.0.0.0/0` route pointing at an internet gateway. a subnet with no such route is private, no matter what you name it. that is the single most important idea in this session.

---

## 4. init, fmt, validate

```bash
terraform init
terraform fmt -check
terraform validate
```

![init and validate](screenshots/Screenshot%202026-10-07%20173958.png)

provider installed from my local plugin cache, formatting clean, and **"Success! The configuration is valid."**

---

## 5. plan - what would be created

```bash
terraform plan -out=tfplan
terraform show -json tfplan | python3 ...
```

![plan and show](screenshots/Screenshot%202026-10-07%20174007.png)

all six resources are planned for creation:

```
# aws_internet_gateway.main          will be created
# aws_route_table.public             will be created
# aws_route_table_association.public will be created
# aws_security_group.web             will be created
# aws_subnet.public                  will be created
# aws_vpc.main                       will be created
Saved the plan to: tfplan
```

`-out=tfplan` saves the plan to a file. that matters in CI: you plan once, a human reviews *that exact plan*, and then `terraform apply tfplan` applies precisely what was reviewed - no risk of the infrastructure drifting between the review and the apply.

`terraform show -json tfplan` turns the plan into json, which is how policy tools (OPA, checkov) check a plan automatically before it is allowed to apply.

### the VPC and subnet in detail

![VPC and subnet plan](screenshots/Screenshot%202026-10-07%20174130.png)

### the security group and route table in detail

![Security group plan](screenshots/Screenshot%202026-10-07%20174140.png)

reading the security group plan:

```
+ resource "aws_security_group" "web" {
    + description = "Security group for Session 19 web traffic"
    + egress = [{
        + cidr_blocks = ["0.0.0.0/0"]
        + description = "Allow outbound IPv4"
        + from_port   = 0
        + protocol    = "-1"      # -1 means all protocols
        + to_port     = 0
      }]
```

and the route table:

```
+ resource "aws_route_table" "public" {
    + region = "ap-south-1"
    + route  = [ ... ]
```

things worth noting:

- `protocol = "-1"` with `from_port = 0, to_port = 0` means **all protocols, all ports** - that is the standard "allow all outbound" rule.
- inbound only opens **80 and 443** from `0.0.0.0/0`. that is correct for a web server; opening **22 (SSH) to 0.0.0.0/0** is the classic mistake, because it exposes SSH to the whole internet.
- security groups are **stateful** - i allow inbound 443 and the response traffic is automatically allowed back out. NACLs are stateless and need both directions written explicitly.

---

## 6. Mini project

the mini project is the same architecture on a different address range (`10.20.0.0/16`) so it could run beside the first VPC without overlapping.

```bash
terraform validate
terraform plan
terraform graph
```

![Mini project](screenshots/Screenshot%202026-10-07%20174059.png)

`terraform graph` prints the dependency graph in DOT format. that graph is why i never have to specify an order - terraform works out that the IGW needs the VPC, the route table needs the IGW, and the association needs both the route table and the subnet, purely from the references between resources.

**CIDR planning** is the reason the mini project uses a different range: if two VPCs (or a VPC and your office network) use overlapping CIDRs, they can never be peered or connected by VPN later. so ranges get allocated deliberately up front, e.g. `10.0.0.0/16` for dev, `10.20.0.0/16` for staging.

---

## Traffic flow of what this plan builds

```
        Internet
            │
    ┌───────▼────────┐
    │ Internet GW    │   attached to the VPC
    └───────┬────────┘
            │   route table:  0.0.0.0/0 -> igw
    ┌───────▼─────────────────────────────┐
    │ VPC 10.0.0.0/16                     │
    │  ┌───────────────────────────────┐  │
    │  │ public subnet 10.0.1.0/24     │  │
    │  │   security group web          │  │
    │  │     in : 80, 443 from any     │  │
    │  │     out: all                  │  │
    │  └───────────────────────────────┘  │
    └─────────────────────────────────────┘
```

to make this production-ready i would add: a second subnet in another AZ, a private subnet for the app/database with a NAT gateway for outbound-only access, and inbound 80/443 restricted to a load balancer's security group instead of `0.0.0.0/0`.

## What i would run with a real account

```bash
export AWS_ACCESS_KEY_ID=...      # or better: an IAM role, never keys in files
export AWS_SECRET_ACCESS_KEY=...
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform destroy      # important - so nothing keeps running
```

a VPC, subnet, IGW, route table and security group are all free; the things that cost money in a VPC are **NAT gateways** (hourly + data) and **elastic IPs** that are not attached to anything. so the habit is always `terraform destroy` after a lab.
