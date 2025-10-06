terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.85.0"
    }
  }
}
provider "aws" {
  region     = "us-east-1"
 
}
 
#EC2#
resource "aws_instance" "web_server" {
  ami           = "ami-08982f1c5bf93d976"  
  instance_type = "t3.micro"
  subnet_id = aws_subnet.public_az1.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags = {
    Name = "TerraformWebServer"
  }
}
 
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}
resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"
   tags = {
    Name = "public-subnet-az1"
  }
}
resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.20.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
 
  tags = {
    Name = "public-subnet-az2"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
 
  tags = {
    Name = "main-igw"
  }
}
 
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id

  }

 
  tags = {
    Name = "public-route-table"
  }
}
 
resource "aws_route_table_association" "public_assoc_az1" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public_assoc_az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.main.id
 
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
    description = "Allow SSH"
  }
 
  ingress {
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
 
resource "aws_db_subnet_group" "default" {
  name       = "main-db-subnet-group-new_1"
   subnet_ids = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
  tags = {
    Name = "MainDBSubnetGroup"
  }
}
 
resource "aws_db_instance" "default" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0.40"
  instance_class       = "db.t3.micro"
  db_name                 = "devops"
  username             = "admin"
  password             = "YourStrongPassword123!"
  db_subnet_group_name = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  skip_final_snapshot  = true
  publicly_accessible  = true
  tags = {
    Name = "MainDBInstance"
  }
}
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow MySQL traffic from web servers"
  vpc_id      = aws_vpc.main.id
 
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]  # allow only EC2 SG
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
 
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role-dev-new_1"
 
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
 
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile_new"
  role = aws_iam_role.ec2_role.name
}
resource "aws_s3_bucket" "tf_state_bucket" {
  bucket = "my-unique-terraformdev-123456"
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

resource "aws_dynamodb_table_2" "tf_lock_table" {
  name         = "terraformlocks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "TerraformLockTable"
  }
}


