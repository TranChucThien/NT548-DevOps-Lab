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
  #shared_credentials_files = [ "C:/Users/chuct/.aws/credentials" ]
}


##############################  VPC ##############################

# Tạo VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# Tạo public subnet
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidr
  map_public_ip_on_launch = true
  depends_on = [ aws_vpc.main ]
  tags = {
    Name = "${var.vpc_name}-public"
  }
}

# Tạo private subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr
  depends_on = [ aws_vpc.main ]
  tags = {
    Name = "${var.vpc_name}-private"
  }
}

# Tạo default security group
resource "aws_security_group" "default" {
  vpc_id = aws_vpc.main.id
  depends_on = [ aws_vpc.main ]
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

  tags = {
    Name = "${var.vpc_name}-default-sg"
  }
}

# Tạo Internet Gateway cho public subnet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  depends_on = [ aws_vpc.main ]
  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# Tạo EIP & NAT Gateway cho private subnet
resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id    = aws_subnet.public.id
  depends_on    = [aws_subnet.public, aws_eip.nat]

  tags = {
    Name = "${var.vpc_name}-nat"
  }
}

##########################  Route Table ##########################

# Tạo Route Table cho public subnet, route tới Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  depends_on = [ aws_internet_gateway.igw ]
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}
# Liên kết Route Table với public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
  depends_on = [ aws_subnet.public, aws_route_table.public ]
}

# Tạo Route Table cho private subnet, route tới NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  depends_on = [ aws_nat_gateway.nat ]

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.vpc_name}-private-rt"
  }
}
# Liên kết Route Table với private subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
  depends_on = [ aws_subnet.private, aws_route_table.private ]
}

########################  Security Groups ########################

resource "aws_security_group" "public_ec2_sg" {
  vpc_id = aws_vpc.main.id

  depends_on = [ aws_vpc.main ]

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.public_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.vpc_name}-public-sg"
  }
}

resource "aws_security_group" "private_ec2_sg" {
  vpc_id = aws_vpc.main.id

  depends_on = [ aws_vpc.main, aws_subnet.public, aws_security_group.public_ec2_sg ]

  ingress {
    cidr_blocks = [aws_subnet.public.cidr_block]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.public_ec2_sg.id]
  }

  ingress {
    cidr_blocks = [aws_subnet.public.cidr_block]
    from_port   = 23
    to_port     = 23
    protocol    = "tcp"
    security_groups = [aws_security_group.public_ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.vpc_name}-private-sg"
  }
}

##############################  EC2 ##############################

resource "aws_instance" "public_instance" {
  depends_on = [ aws_security_group.public_ec2_sg, aws_subnet.public ]
  ami           = "ami-0e86e20dae9224db8"
  instance_type = "t2.micro"
  key_name = "public-ec2-key"
  
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.public_ec2_sg.id]

  tags = {
    Name = "${var.vpc_name}-public-instance"
  }
}

resource "aws_instance" "private_instance" {
  depends_on = [ aws_security_group.private_ec2_sg, aws_subnet.public ]
  ami           = "ami-0e86e20dae9224db8"
  instance_type = "t2.micro"
  key_name = "private-ec2-key"
  
  subnet_id     = aws_subnet.private.id
  vpc_security_group_ids = [ aws_security_group.private_ec2_sg.id ]
  
  tags = {
    Name = "${var.vpc_name}-private-instance"
  }
}

