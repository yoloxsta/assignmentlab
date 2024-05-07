# Configure the AWS Provider
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
  region = "us-east-1"     #change region as per you requirement
}

# 1.create vpc

resource "aws_vpc" "dev-vpc" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "dev_cidr_block"
  }
}
# 2.Create internet Gateway

resource "aws_internet_gateway" "dev-gw" {
  vpc_id = aws_vpc.dev-vpc.id
}
# 3.Create Custom Route Table

resource "aws_route_table" "dev-route-table" {
  vpc_id = aws_vpc.dev-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.dev-gw.id
  }

  tags = {
    Name = "dev-route-table"
  }
}
# 4.Create a subnet

resource "aws_subnet" "dev-subnet-1" {
  vpc_id     = aws_vpc.dev-vpc.id
  cidr_block = "10.1.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "dev-subnet"
  }
}

# 5. Associate subnet with Route Table

resource "aws_route_table_association" "dev-rta" {
  subnet_id      = aws_subnet.dev-subnet-1.id
  route_table_id = aws_route_table.dev-route-table.id
}

# 6. Create Security Group to allow port 22,80,443

resource "aws_security_group" "allow-web-traffic" {
  name        = "allow_Web_Traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.dev-vpc.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web_server"
  }
}
# 7. Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "dev-web-server-nic" {
  subnet_id       =  aws_subnet.dev-subnet-1.id
  private_ips     = ["10.1.1.50"]
  security_groups = [aws_security_group.allow-web-traffic.id]
}
# 8. Assign an elastic IP to the network interface created in step 7


resource "aws_eip" "one" {
  domain                    =  "vpc"
  network_interface         = aws_network_interface.dev-web-server-nic.id
  associate_with_private_ip = "10.1.1.50"
  depends_on = [aws_internet_gateway.dev-gw]
}
# 9. Create Ubuntu web Server and install/enable apache2
