terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

##############################  VPC ##############################

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# Enable VPC flow logging
resource "aws_flow_log" "vpc_flow_log" {
  log_destination_type = "cloud-watch-logs"
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"

  log_group_name = "/aws/vpc/flow-logs"
  iam_role_arn   = var.iam_role_arn # Ensure an IAM role for VPC Flow Logs
}

############################  Subnets ############################

# Create public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = false  # Ensures no public IP assigned by default
  depends_on              = [aws_vpc.main]
  
  tags = {
    Name = "${var.vpc_name}-public"
  }
}

# Create private subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr
  depends_on = [aws_vpc.main]
  
  tags = {
    Name = "${var.vpc_name}-private"
  }
}

# Restrict all traffic in default security group
resource "aws_security_group" "default" {
  vpc_id = aws_vpc.main.id
  depends_on = [aws_vpc.main]

  # No ingress or egress rules to block all traffic

  tags = {
    Name = "${var.vpc_name}-default-sg"
  }
}

# Create Internet Gateway for public subnet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  depends_on = [aws_vpc.main]

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

########################  Security Groups ########################

# Public EC2 Security Group
resource "aws_security_group" "public_ec2_sg" {
  vpc_id = aws_vpc.main.id
  depends_on = [aws_vpc.main]

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.public_ip]
    description = "Allow SSH access from specified IP for public instances"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic for public instances"
  }

  tags = {
    Name = "${var.vpc_name}-public-sg"
  }
}

# Private EC2 Security Group
resource "aws_security_group" "private_ec2_sg" {
  vpc_id = aws_vpc.main.id
  depends_on = [aws_vpc.main]

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public.cidr_block]
    description = "Allow SSH access from public subnet for private instances"
  }

  ingress {
    from_port   = 23
    to_port     = 23
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public.cidr_block]
    description = "Allow custom port access from public subnet for private instances"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic for private instances"
  }

  tags = {
    Name = "${var.vpc_name}-private-sg"
  }
}

##############################  EC2 ##############################

resource "aws_instance" "public_instance" {
  depends_on = [aws_security_group.public_ec2_sg, aws_subnet.public]
  ami           = "ami-0e86e20dae9224db8"
  instance_type = "t2.micro"
  key_name      = "public-ec2-key"
  ebs_optimized = true # Ensures EBS optimization
  monitoring    = true # Enable detailed monitoring

  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.public_ec2_sg.id]

  iam_instance_profile = aws_iam_instance_profile.public_ec2_role.name # Attach IAM role for security

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true # Ensures root volume is encrypted
  }

  tags = {
    Name = "${var.vpc_name}-public-instance"
  }
}

resource "aws_instance" "private_instance" {
  depends_on = [aws_security_group.private_ec2_sg, aws_subnet.public]
  ami           = "ami-0e86e20dae9224db8"
  instance_type = "t2.micro"
  key_name      = "private-ec2-key"
  ebs_optimized = true # Ensures EBS optimization
  monitoring    = true # Enable detailed monitoring

  subnet_id     = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private_ec2_sg.id]

  iam_instance_profile = aws_iam_instance_profile.private_ec2_role.name # Attach IAM role for security

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true # Ensures root volume is encrypted
  }

  tags = {
    Name = "${var.vpc_name}-private-instance"
  }
}
