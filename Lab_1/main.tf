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

# Create default security group with descriptions and restrict all traffic by default
resource "aws_security_group" "default" {
  vpc_id = aws_vpc.main.id
  depends_on = [aws_vpc.main]

  # No ingress rules to restrict all incoming traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

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

# Create EIP & NAT Gateway for private subnet
resource "aws_eip" "nat" {
  vpc = aws_vpc.main.id # Attach EIP to VPC directly
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_subnet.public, aws_eip.nat]

  tags = {
    Name = "${var.vpc_name}-nat"
  }
}

##########################  Route Table ##########################

# Create Route Table for public subnet, route to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  depends_on = [aws_internet_gateway.igw]
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

# Associate Route Table with public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
  depends_on     = [aws_subnet.public, aws_route_table.public]
}

# Create Route Table for private subnet, route to NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  depends_on = [aws_nat_gateway.nat]
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.vpc_name}-private-rt"
  }
}

# Associate Route Table with private subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
  depends_on     = [aws_subnet.private, aws_route_table.private]
}

########################  Security Groups ########################

resource "aws_security_group" "public_ec2_sg" {
  vpc_id = aws_vpc.main.id
  depends_on = [aws_vpc.main]

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.public_ip]
    description = "Allow SSH access from my IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.vpc_name}-public-sg"
  }
}

resource "aws_security_group" "private_ec2_sg" {
  vpc_id = aws_vpc.main.id
  depends_on = [aws_vpc.main]

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public.cidr_block]
    description = "Allow SSH access from public subnet"
  }

  ingress {
    from_port   = 23
    to_port     = 23
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public.cidr_block]
    description = "Allow custom access from public subnet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
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
