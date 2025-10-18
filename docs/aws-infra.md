# AWS Terraform Deployment

This page documents the **exact AWS infrastructure** used by Mood Tracker and how to deploy it with **Terraform**.  
It provisions a **private RDS PostgreSQL**, a **private Bastion (EC2) managed by SSM**, **VPC interface endpoints** required for SSM, and all networking/Security Groups.

> Password strategy: **AWS Secrets Manager** (the DB password is read from an existing secret named `rds-postgres-password`).

---

## 🔎 Architecture Overview

```

┌───────────────────────────────────────────────────────────────────┐
│ AWS Region: eu-west-3 (Paris)                                     │
│                                                                   │
│  VPC 10.0.0.0/16                                                  │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ Private Subnets:                                            │  │
│  │  - subnet_a (10.0.1.0/24, AZ a)                             │  │
│  │  - subnet_b (10.0.2.0/24, AZ b)                             │  │
│  │                                                             │  │
│  │  Bastion EC2 (no public IP)                                 │  │
│  │   • IAM role: AmazonSSMManagedInstanceCore                  │  │
│  │   • SSM Agent                                               │  │
│  │   • Security Group: bastion-private-sg (egress only)        │  │
│  │                                                             │  │
│  │  RDS PostgreSQL (private)                                   │  │
│  │   • Subnet group: [subnet_a, subnet_b]                      │  │
│  │   • Security Group: rds-security-group                      │  │
│  │   • Ingress 5432 from bastion SG only                       │  │
│  │                                                             │  │
│  │  VPC Interface Endpoints:                                   │  │
│  │   • com.amazonaws.eu-west-3.ssm                             │  │
│  │   • com.amazonaws.eu-west-3.ssmmessages                     │  │
│  │   • com.amazonaws.eu-west-3.ec2messages                     │  │
│  │   • (Gateway) S3 endpoint for SSM artifacts                 │  │
│  └─────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────┘

```

**Why this design?**
- **No public exposure** of the database.
- **SSM-only access** to Bastion (no SSH keys).
- **Least-privilege security groups** (Bastion SG → RDS SG on 5432).
- **VPC endpoints** ensure SSM works even without Internet/NAT.

---

## 📂 Files Overview (as-is)

Your Terraform is split across the following files:

- `provider.tf` – Providers & versions
- `variables.tf` – Input variables (db username, region)
- `network.tf` – VPC, private subnets, DB subnet group
- `route.tf` – Private route table & associations
- `security.tf` – SGs for Bastion & RDS, and ingress rule
- `bastion.tf` – Bastion AMI, IAM role/profile, EC2 instance
- `endpoints.tf` – SSM/EC2Messages/SSMMessages/S3 VPC endpoints (+ SG)
- `secrets.tf` – Data sources to read the DB password from Secrets Manager
- `rds.tf` – RDS PostgreSQL instance (private)
- `outputs.tf` – Useful outputs (DB endpoint, Secret ARN, Bastion instance id)
- `main.tf` – (intentionally empty in your layout)

> Region: **eu-west-3**. Adjust via `provider.tf` or pass `-var aws_region=...` if you wire it into the provider.

---

## 🔐 Secrets (AWS Secrets Manager)

This setup **expects** a secret named `rds-postgres-password` to already exist.  
The RDS instance reads the admin password via:

```hcl
data "aws_secretsmanager_secret" "db_password" {
  name = "rds-postgres-password"
}

data "aws_secretsmanager_secret_version" "db_password_value" {
  secret_id = data.aws_secretsmanager_secret.db_password.id
}
````

Create/update the secret if needed:

```bash
aws secretsmanager create-secret \
  --name rds-postgres-password \
  --secret-string 'YourStrong#Password123' \
  --region eu-west-3
# or update:
aws secretsmanager put-secret-value \
  --secret-id rds-postgres-password \
  --secret-string 'YourStrong#Password123' \
  --region eu-west-3
```

---

## 🧩 Key Snippets (exact from your code)

### Provider & Versions (`provider.tf`)

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = "eu-west-3" # Paris
}
```

### Variables (`variables.tf`)

```hcl
variable "db_username" {
  description = "Nom de l'utilisateur admin PostgreSQL"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}
```

### Networking (`network.tf`)

```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "main-vpc" }
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = false
  tags = { Name = "private-subnet-a" }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-3b"
  map_public_ip_on_launch = false
  tags = { Name = "private-subnet-b" }
}

resource "aws_db_subnet_group" "postgres_subnets" {
  name       = "postgres-subnet-group"
  subnet_ids = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  description = "Private subnets for PostgreSQL RDS"
  tags = { Name = "postgres-subnet-group" }
}
```

### Routes (`route.tf`)

```hcl
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "private-route-table" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}
```

### Security Groups (`security.tf`)

```hcl
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Allow PostgreSQL access from bastion only"
  vpc_id      = aws_vpc.main.id

  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "rds-sg" }
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion-private-sg"
  description = "Private bastion for connecting via SSM"
  vpc_id      = aws_vpc.main.id

  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "bastion-sg" }
}

resource "aws_security_group_rule" "rds_from_bastion" {
  type                     = "ingress"
  description              = "Allow traffic from bastion to RDS PostgreSQL"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
}
```

### Bastion & IAM (`bastion.tf`)

```hcl
data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name" values = ["amzn2-ami-hvm-*-x86_64-gp2"] }
}

resource "aws_iam_role" "bastion_role" {
  name = "bastion-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm_core" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion-ssm-instance-profile"
  role = aws_iam_role.bastion_role.name
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_a.id
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.bastion_profile.name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y postgresql
              EOF

  tags = { Name = "bastion-private" }
}
```

### VPC Endpoints (`endpoints.tf`)

```hcl
data "aws_region" "current" {}

resource "aws_security_group" "vpce_sg" {
  name   = "vpc-endpoints-ssm-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow HTTPS from bastion"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "vpce-ssm-sg" }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  route_table_ids = [aws_vpc.main.default_route_table_id]
}
```

### RDS (`rds.tf`)

```hcl
resource "aws_db_instance" "postgres" {
  identifier             = "my-postgres-db"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20

  username               = var.db_username
  password               = data.aws_secretsmanager_secret_version.db_password_value.secret_string

  db_subnet_group_name   = aws_db_subnet_group.postgres_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = { Name = "postgres-rds" }
}
```

### Outputs (`outputs.tf`)

```hcl
output "db_endpoint" {
  description = "Endpoint PostgreSQL"
  value       = aws_db_instance.postgres.address
}
output "db_secret_arn" {
  description = "ARN du secret contenant le mot de passe PostgreSQL"
  value       = data.aws_secretsmanager_secret.db_password.arn
}
output "bastion_instance_id" {
  description = "ID de l'instance bastion pour tunnel SSM"
  value       = aws_instance.bastion.id
}
```

---

## 🚀 Deploy

1. **Create/Update** the secret:

```bash
aws secretsmanager create-secret \
  --name rds-postgres-password \
  --secret-string 'YourStrong#Password123' \
  --region eu-west-3 || true

# or update if it already exists
aws secretsmanager put-secret-value \
  --secret-id rds-postgres-password \
  --secret-string 'YourStrong#Password123' \
  --region eu-west-3
```

2. **Apply Terraform**:

```bash
cd infra
terraform init
terraform apply
```

3. **Get outputs**:

```bash
terraform output -raw bastion_instance_id
terraform output -raw db_endpoint
terraform output -raw db_secret_arn
```

---

## 🧪 Validate SSM & RDS

Open a **local** SSM port forward (optional, for quick test from laptop):

```bash
aws ssm start-session \
  --target $(terraform output -raw bastion_instance_id) \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["'$(terraform output -raw db_endpoint)'"],"portNumber":["5432"],"localPortNumber":["5432"]}'
```

Then:

```bash
psql -h 127.0.0.1 -U <db_user> -d postgres -p 5432 sslmode=require
# Password = value stored in Secrets Manager
```

> In Kubernetes, use the **SSM Proxy chart** and connect to
> `postgres-rds.default.svc.cluster.local:5432`.

---

## 🔐 Security Notes

* **No public IPs** on Bastion/RDS.
* RDS allows inbound **only from Bastion SG** on port 5432.
* Use **AWS RDS CA bundle** for TLS (`verify-ca`) in production:

  * [https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem](https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem)
* Terminate stale sessions:

  ```bash
  aws ssm describe-sessions --state Active
  aws ssm terminate-session --session-id <ID>
  ```

---

## 🧰 Troubleshooting

| Symptom                                        | Likely Cause             | Fix                                                                    |
| ---------------------------------------------- | ------------------------ | ---------------------------------------------------------------------- |
| `InvalidSubnet: No default subnet`             | RDS expects subnet group | Ensure `aws_db_subnet_group` exists & is set                           |
| `Cannot create publicly accessible DBInstance` | No IGW/NAT (private)     | RDS is intended **private** → do not set `publicly_accessible=true`    |
| SSM sessions very slow                         | Missing VPC endpoints    | Ensure `ssm`, `ssmmessages`, `ec2messages`, and gateway `s3` endpoints |
| `DependencyViolation` SG delete                | SG still referenced      | Detach from RDS/EC2, remove rules, retry destroy                       |
| `no pg_hba.conf entry ... no encryption`       | SSL required by RDS      | Use `sslmode=require` or `verify-ca`                                   |
| Timeout to RDS                                 | SG or tunnel issue       | Check `aws_security_group_rule.rds_from_bastion` and SSM logs          |

---

## 🗑️ Destroy

```bash
cd infra
terraform destroy
```

> If `destroy` is blocked by dependencies (SG, endpoints), remove dependents first (e.g., RDS) and retry.

---

```


```

