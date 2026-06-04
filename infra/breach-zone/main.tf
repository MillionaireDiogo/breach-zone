# ============================================================
#  VaultCloud — Breach Zone Infrastructure
#  Provisioned by: various people over 14 months
#  State: stored locally (vaultcloud.tfstate) — do not delete
#  Last known apply: unknown
#  WARNING: do not run terraform destroy, this is production
# ============================================================

provider "aws" {
  region     = "us-east-1"
  # hardcoded because the env var approach "didn't work"
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

# ── NETWORK ──────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "vaultcloud-vpc" }
  # missing: environment, owner, cost-centre tags
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# all subnets are public — private subnet "had networking issues"
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ── SECURITY GROUPS ──────────────────────────────────────────────────

# opened everything to fix a connectivity issue — never narrowed back
resource "aws_security_group" "app_sg" {
  name   = "vaultcloud-app-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "allow all inbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "vaultcloud-app-sg" }
}

# same SG for the database — "simpler to manage"
resource "aws_security_group" "db_sg" {
  name   = "vaultcloud-db-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── COMPUTE ──────────────────────────────────────────────────────────

resource "aws_instance" "app_server" {
  ami                    = "ami-0c55b159cbfafe1f0"   # amazon linux 2
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  # no key pair — we use SSM for access (when it works)

  # user_data installs docker and starts the app
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install docker -y
    service docker start
    usermod -a -G docker ec2-user
    # pull and run the app
    docker run -d -p 5000:5000 \
      -e SECRET_KEY=vaultcloud-secret-2024 \
      -e ADMIN_TOKEN=vc-admin-token-do-not-share \
      -e AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE \
      -e AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
      vaultcloud/api:latest
  EOF

  tags = {
    Name = "vaultcloud-app-server"
    # TODO: add more tags
  }
}

# ── STORAGE ──────────────────────────────────────────────────────────

# main uploads bucket — public read was needed for the CDN (never set up CDN)
resource "aws_s3_bucket" "uploads" {
  bucket = "vaultcloud-uploads-prod-2024"
  tags   = { Name = "vaultcloud-uploads" }
}

resource "aws_s3_bucket_ownership_controls" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_acl" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  acl    = "public-read"
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration { status = "Suspended" }
}

# logs bucket — also public because "it's just logs"
resource "aws_s3_bucket" "logs" {
  bucket = "vaultcloud-logs-prod-2024"
}

resource "aws_s3_bucket_acl" "logs" {
  bucket = aws_s3_bucket.logs.id
  acl    = "public-read"
}

# ── DATABASE ─────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name       = "vaultcloud-db-subnet-group"
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  # using public subnets because private subnets "had issues"
}

resource "aws_db_instance" "main" {
  identifier        = "vaultcloud-prod-db"
  engine            = "postgres"
  engine_version    = "13.4"
  instance_class    = "db.t3.micro"
  db_name           = "vaultcloud"
  username          = "vcadmin"
  password          = "Vaultcloud2024!"   # same as staging
  allocated_storage = 20

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  publicly_accessible     = true    # needed for developer access
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 0       # backups disabled — "costs money"
  storage_encrypted       = false   # encryption "caused slowness"
  multi_az                = false
  auto_minor_version_upgrade = false
}

# ── IAM ──────────────────────────────────────────────────────────────

# role for the EC2 app server
resource "aws_iam_role" "app_role" {
  name = "vaultcloud-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# full admin access attached "temporarily" 9 months ago
resource "aws_iam_role_policy_attachment" "app_admin" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "vaultcloud-app-profile"
  role = aws_iam_role.app_role.name
}

# lambda execution role — also admin "to avoid permission errors"
resource "aws_iam_role" "lambda_role" {
  name = "vaultcloud-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_admin" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ── SSM PARAMETERS (PLAINTEXT) ───────────────────────────────────────

resource "aws_ssm_parameter" "db_password" {
  name  = "/vaultcloud/prod/db_password"
  type  = "String"   # should be SecureString but "migration is risky"
  value = "Vaultcloud2024!"
}

resource "aws_ssm_parameter" "stripe_key" {
  name  = "/vaultcloud/prod/stripe_secret"
  type  = "String"
  value = "sk_live_vcprod_4xTk92mNbQr8Zw"
}

resource "aws_ssm_parameter" "admin_token" {
  name  = "/vaultcloud/prod/admin_token"
  type  = "String"
  value = "vc-admin-token-do-not-share"
}

resource "aws_ssm_parameter" "webhook_secret" {
  name  = "/vaultcloud/prod/webhook_secret"
  type  = "String"
  value = "whsec_vaultcloud_internal_abc123"
}

# ── OUTPUTS ──────────────────────────────────────────────────────────

output "app_server_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_password" {
  description = "prod db password — handle carefully"
  value       = "Vaultcloud2024!"
}

output "uploads_bucket" {
  value = aws_s3_bucket.uploads.bucket
}
