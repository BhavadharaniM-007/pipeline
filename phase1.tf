terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.85.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Reference existing VPC instead of creating a new one
data "aws_vpc" "existing" {
  id = "vpc-0cb3b9f14e71a699b"  # <-- Replace with your existing VPC ID
}

# Subnets
resource "aws_subnet" "public_az1" {
  vpc_id                  = data.aws_vpc.existing.id
  cidr_block              = "10.0.30.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "public-subnet-az1"
  }
}

data "aws_subnet" "public_az2" {
  filter {
    name   = "cidr-block"
    values = ["10.0.20.0/24"]
  }

  filter {
    name   = "vpc-id"
    values = ["vpc-0cb3b9f14e71a699b"] # Replace with your VPC ID
  }
}

# Internet Gateway
data "aws_internet_gateway" "existing_igw" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}


# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = data.aws_vpc.existing.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.existing_igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_assoc_az1" {
  subnet_id      =data.aws_subnet.public_az1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_az2" {
  subnet_id      = data.aws_subnet.public_az2.id

  route_table_id = aws_route_table.public_rt.id
}

# Security Group for EC2 instances (SSH + HTTP allowed)
resource "aws_security_group" "web_sg" {
  name        = "web-sg-v5"
  description = "Allow SSH and HTTP"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

# Security Group for RDS (MySQL only from web_sg)
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow MySQL traffic from web servers"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role-dev-new-233"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach AmazonEC2ContainerRegistryReadOnly policy (example)
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile_new_1"
  role = aws_iam_role.ec2_role.name
}

# Amazon Linux 2 EC2 instance
resource "aws_instance" "web_server" {
  ami                         = "ami-08982f1c5bf93d976"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_az1.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  associate_public_ip_address = true

  tags = {
    Name = "TerraformWebServer_76"
  }
}

# Ubuntu EC2 instance
resource "aws_instance" "ubuntu" {
  ami                         = "ami-042e8287309f5df03"  # Ubuntu Server 20.04 LTS
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_az2.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "UbuntuInstance-18"
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "default" {
  name       = "main-db-subnet-group-new-1"
  subnet_ids = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]

  tags = {
    Name = "MainDBSubnetGroup"
  }
}

# RDS Instance
resource "aws_db_instance" "default" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0.40"
  instance_class         = "db.t3.micro"
  db_name                = "devops"
  username               = "admin"
  password               = "YourStrongPassword123!"
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = true

  tags = {
    Name = "MainDBInstance"
  }
}

# S3 Bucket for Terraform state
resource "aws_s3_bucket" "tf_state_bucket" {
  bucket = "bhar-123"

  tags = {
    Name = "Terraformdev_12"
  }
}

resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_sse" {
  bucket = aws_s3_bucket.tf_state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB Table for Terraform Locking
resource "aws_dynamodb_table" "tf_lock_table" {
  name         = "terraformlocks_2123"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "TerraformLockTable-12234e"
  }
}

# Outputs for public IPs to use dynamically (for Ansible inventory or GitHub Secrets update)
output "web_server_public_ip" {
  description = "Public IP of Amazon Linux web server"
  value       = aws_instance.web_server.public_ip
}

output "ubuntu_public_ip" {
  description = "Public IP of Ubuntu instance"
  value       = aws_instance.ubuntu.public_ip
}
