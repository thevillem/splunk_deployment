# Set the region to deploy the resource in
provider "aws" {
  region = "us-east-1"
}

# Variables for

data "local_file" "public_ip" {
  filename = "${path.module}/public_ip.txt"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  default = "192.168.0.0/16"
}

variable "splunk_subnet_cidr" {
  description = "CIDR for the Splunk subnet"
  default = "192.168.1.0/24"
}

# Define our VPC
resource "aws_vpc" "splunk-vpc" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = true

  tags {
    Name = "splunk-vpc"
  }
}

# Define the Splunk subnet
resource "aws_subnet" "splunk-subnet" {
  vpc_id = "${aws_vpc.splunk-vpc.id}"
  cidr_block = "${var.splunk_subnet_cidr}"
  availability_zone = "us-east-1a"

  tags {
    Name = "Splunk Subnet"
  }
}

# Define the internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.splunk-vpc.id}"

  tags {
    Name = "VPC IGW"
  }
}

# Define the route table
resource "aws_route_table" "splunk-rt" {
  vpc_id = "${aws_vpc.splunk-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "Splunk Subnet RT"
  }
}

# Assign the route table to the public Subnet
resource "aws_route_table_association" "web-public-rt" {
  subnet_id = "${aws_subnet.splunk-subnet.id}"
  route_table_id = "${aws_route_table.splunk-rt.id}"
}

# Define the security group for splunk subnet
resource "aws_security_group" "sgsplunk" {
  name = "Splunk_Web Subnet"
  description = "Allow incoming HTTP connections & SSH access"

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["${data.local_file.public_ip.content}/32"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks =  ["${data.local_file.public_ip.content}/32"]
  }

  vpc_id="${aws_vpc.splunk-vpc.id}"

  tags {
    Name = "Splunk_Web SG"
  }
}

# Create the Splunk Indexer EC2 Instance using the below
# ami-id && instance_type
resource "aws_instance" "splunk_indexer" {
  ami           = "ami-b374d5a5"
  instance_type = "t2.micro"
  key_name = "splunk_indexer"
  subnet_id = "${aws_subnet.splunk-subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.sgsplunk.id}"]
  associate_public_ip_address = true

  tags {
    Name = "splunk-indxr"
  }

  provisioner "local-exec" {
    command = "echo ${aws_instance.splunk_indexer.public_ip} > splunk_indexer_ip_address.txt"
  }
}

