provider "aws" {
  region = "us-east-1"
  shared_credentials_files = [ "C:/Users/Quan/.aws/credentials" ]
}


run "create_vpc" {
    command = apply

    assert {
        condition = aws_vpc.main.tags.Name == "21520421-vpc"
        error_message = "VPC name is not correct"
    }
    assert {
        condition = aws_vpc.main.cidr_block == "10.0.0.0/16"
        error_message = "VPC CIDR block is not correct"
    }
}

run "create_public_subnet" {
    command = apply

    assert {
        condition = aws_subnet.public.tags.Name == "21520421-vpc-public"
        error_message = "Public subnet name is not correct"
    }

    assert {
        condition = aws_subnet.public.cidr_block == "10.0.1.0/24"
        error_message = "Public subnet CIDR block is not correct"
    }
}

run "create_private_subnet" {
    command = apply

    assert {
        condition = aws_subnet.private.tags.Name == "21520421-vpc-private"
        error_message = "Public subnet name is not correct"
    }

    assert {
        condition = aws_subnet.private.cidr_block == "10.0.2.0/24"
        error_message = "Public subnet CIDR block is not correct"
    }
}

run "create_default_security_group" {
    command = apply

    assert {
        condition = aws_security_group.default.tags.Name == "21520421-vpc-default-sg"
        error_message = "Default security group name is not correct"
    }
}

run "create_internet_gateway" {
    command = apply

    assert {
        condition = aws_internet_gateway.igw.tags.Name == "21520421-vpc-igw"
        error_message = "Internet gateway name is not correct"
    }
}

run "create_nat_gateway" {
    command = apply

    assert {
        condition = aws_nat_gateway.nat.tags.Name == "21520421-vpc-nat"
        error_message = "NAT gateway name is not correct"
    }
}

run "create_route_tables" {
    command = apply

    assert {
        condition = aws_route_table.public.tags.Name == "21520421-vpc-public-rt"
        error_message = "Public route table name is not correct"
    }

    assert {
        condition = aws_route_table.private.tags.Name == "21520421-vpc-private-rt"
        error_message = "Private route table name is not correct"
    }
}

run "create_instance_security_group" {
    command = apply

    assert {
        condition = aws_security_group.public_ec2_sg.tags.Name == "21520421-vpc-public-sg"
        error_message = "Public instance security group name is not correct"
    }

    assert {
        condition = aws_security_group.private_ec2_sg.tags.Name == "21520421-vpc-private-sg"
        error_message = "Private instance security group name is not correct"
    }
}

run "create_ec2_instances" {
    command = apply

    assert {
        condition = aws_instance.public_instance.tags.Name == "21520421-vpc-public-instance"
        error_message = "Public EC2 instance name is not correct"
    }

    assert {
        condition = aws_instance.private_instance.tags.Name == "21520421-vpc-private-instance"
        error_message = "Private EC2 instance name is not correct"
    }
}