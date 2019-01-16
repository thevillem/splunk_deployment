# Set the region to deploy the resource in
provider "aws" {
  region = "us-east-1"
}

# Variables for

data "local_file" "public_ip" {
  filename = "${path.module}/public_ip.txt"
}

variable "splunk_ssh_key" {
  description = "Path to the Splunk SSH key"
  default = "./splunk_hosts.pem"
}

variable "vpc_cidr" {
  description = "CIDR for the Splunk VPC"
  default = "192.168.0.0/16"
}

variable "splunk_subnet_cidr" {
  description = "CIDR for the Splunk Indxr subnet"
  default = "192.168.1.0/24"
}

# Define our VPC
resource "aws_vpc" "splunk-vpc" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = true

  tags {
    Name = "splunk-class-vpc"
  }
}

# Define the internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.splunk-vpc.id}"

  tags {
    Name = "VPC IGW"
  }
}

# Define the Splunk Indexer subnet
resource "aws_subnet" "splunk-subnet" {
  vpc_id = "${aws_vpc.splunk-vpc.id}"
  cidr_block = "${var.splunk_subnet_cidr}"
  availability_zone = "us-east-1a"

  tags {
    Name = "Splunk Indxr Subnet"
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
resource "aws_route_table_association" "splunk-public-rt" {
  subnet_id = "${aws_subnet.splunk-subnet.id}"
  route_table_id = "${aws_route_table.splunk-rt.id}"
}

# Define the security group for splunk subnets
resource "aws_security_group" "sgsplunk" {
  name = "Splunk Security Group"
  description = "Allow incoming HTTP connections & SSH access"

  vpc_id="${aws_vpc.splunk-vpc.id}"

  tags {
    Name = "Splunk SG"
  }
}

resource "aws_security_group_rule" "allow_ssh_traffic_in" {
  from_port = 22
  protocol = "tcp"
  security_group_id = "${aws_security_group.sgsplunk.id}"
  cidr_blocks = ["${data.local_file.public_ip.content}/32"]
  to_port = 22
  type = "ingress"
}

resource "aws_security_group_rule" "allow_http_traffic_in" {
  from_port = 8080
  protocol = "tcp"
  security_group_id = "${aws_security_group.sgsplunk.id}"
  cidr_blocks = ["${data.local_file.public_ip.content}/32"]
  to_port = 8080
  type = "ingress"
}

resource "aws_security_group_rule" "allow_internal_sg_traffic_in" {
  from_port = 0
  protocol = "-1"
  security_group_id = "${aws_security_group.sgsplunk.id}"
  source_security_group_id = "${aws_security_group.sgsplunk.id}"
  to_port = 0
  type = "ingress"
}

resource "aws_security_group_rule" "allow_internal_sg_traffic_out" {
  from_port = 0
  protocol = "-1"
  security_group_id = "${aws_security_group.sgsplunk.id}"
  source_security_group_id = "${aws_security_group.sgsplunk.id}"
  to_port = 0
  type = "egress"
}

resource "aws_security_group_rule" "allow_all_out" {
  from_port = 0
  protocol = "-1"
  security_group_id = "${aws_security_group.sgsplunk.id}"
  cidr_blocks = ["0.0.0.0/0"]
  to_port = 0
  type = "egress"
}

# Create the Splunk Indexer EC2 Instance using the below
# ami-id && instance_type
resource "aws_instance" "splunk_indexer" {
  ami           = "ami-009d6802948d06e52"
  instance_type = "t2.micro"
  key_name = "splunk_hosts"
  subnet_id = "${aws_subnet.splunk-subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.sgsplunk.id}"]
  associate_public_ip_address = true

  tags {
    Name = "splunk-indxr"
  }

    provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "cd /var/tmp/",
      "curl -O https://s3.amazonaws.com/splunk-class-uf/splunk-7.2.3-06d57c595b80-Linux-x86_64.tgz",
      "curl -O https://s3.amazonaws.com/splunk-class-uf/indxr-conf.tgz",
      "curl -O https://s3.amazonaws.com/splunk-class-uf/indxr_install.sh"
    ]

    connection {
      type = "ssh"
      user = "ec2-user"
      private_key = "${file("./splunk_hosts.pem")}"
    }

  }

  provisioner "local-exec" {
    command = "echo ${aws_instance.splunk_indexer.public_ip} > splunk_indexer_ip_address.txt"
  }
}

resource "aws_instance" "splunk_f1" {
  ami           = "ami-009d6802948d06e52"
  instance_type = "t2.micro"
  key_name = "splunk_hosts"
  subnet_id = "${aws_subnet.splunk-subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.sgsplunk.id}"]
  associate_public_ip_address = true

  tags {
    Name = "splunk-f1"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "cd /var/tmp/",
      "curl -O https://s3.amazonaws.com/splunk-class-uf/splunkforwarder-7.2.3-06d57c595b80-Linux-x86_64.tgz",
      "curl -O https://s3.amazonaws.com/splunk-class-uf/uf-install.sh"
    ]

    connection {
      type = "ssh"
      user = "ec2-user"
      private_key = "${file("./splunk_hosts.pem")}"
    }
  }

  provisioner "local-exec" {
    command = "echo ${aws_instance.splunk_f1.public_ip} >> splunk_forwarder_ip_address.txt"
  }
}