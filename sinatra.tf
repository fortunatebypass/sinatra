provider "aws" {
  region = "ap-southeast-2"
}

variable "ssh_from_public_ip_cidr" {
  description = "Public IP address/CIDR to allow SSH access from E.g.: x.x.x.x/32"
}

variable "vpc_cidr" {
  description = "IP CIDR for the VPC and single subnet - E.g.: 172.25.0.0/24"
}

variable "ssh_public_key" {
  description = "SSH Public Key for initial EC2 SSH access - E.g.: 'ssh-rsa XXXXX user@host'"
}

data "aws_availability_zones" "available" {}

data "aws_ami" "intel_clear_linux" {
  most_recent = true

  # Owner: Intel
  owners = ["679593333241"]

  filter {
    name = "name"

    values = [
      "clear-*",
    ]
  }
}

resource "aws_key_pair" "sinatra" {
  key_name   = "sinatra_key"
  public_key = "${var.ssh_public_key}"
}

resource "aws_vpc" "vpc_name" {
  cidr_block                       = "${var.vpc_cidr}"
  assign_generated_ipv6_cidr_block = true

  tags {
    Name = "sinatra_vpc"
  }
}

resource "aws_internet_gateway" "sinatra_ig" {
  vpc_id = "${aws_vpc.vpc_name.id}"

  tags {
    Name = "sinatra_ig"
  }
}

resource "aws_subnet" "vpc_sn" {
  vpc_id                          = "${aws_vpc.vpc_name.id}"
  cidr_block                      = "${var.vpc_cidr}"
  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.vpc_name.ipv6_cidr_block, 8, 1)}"
  assign_ipv6_address_on_creation = true
  availability_zone               = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "vpc_sn"
  }
}

resource "aws_route_table" "vpc_sn_rt" {
  vpc_id = "${aws_vpc.vpc_name.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.sinatra_ig.id}"
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = "${aws_internet_gateway.sinatra_ig.id}"
  }

  tags {
    Name = "vpc_sn_rt"
  }
}

resource "aws_route_table_association" "vpc_sn_rt_assn" {
  subnet_id      = "${aws_subnet.vpc_sn.id}"
  route_table_id = "${aws_route_table.vpc_sn_rt.id}"
}

resource "aws_security_group" "public_sg" {
  name        = "apse2_web_public_sg"
  description = "Public Security group REA Web Instances"
  vpc_id      = "${aws_vpc.vpc_name.id}"

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    ipv6_cidr_blocks = [
      "::/0",
    ]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "${var.ssh_from_public_ip_cidr}",
      "${aws_subnet.vpc_sn.cidr_block}",
    ]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    ipv6_cidr_blocks = [
      "${aws_subnet.vpc_sn.ipv6_cidr_block}",
    ]
  }

  egress {
    # allow all traffic out
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  egress {
    # allow all traffic out
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"

    ipv6_cidr_blocks = [
      "::/0",
    ]
  }

  tags {
    Name = "apse2_web_public_sg"
  }
}

resource "aws_instance" "web" {
  ami                         = "${data.aws_ami.intel_clear_linux.id}"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.vpc_sn.id}"
  security_groups             = ["${aws_security_group.public_sg.id}"]
  associate_public_ip_address = true
  key_name                    = "${aws_key_pair.sinatra.key_name}"
  ipv6_address_count          = 1

  root_block_device {
    volume_type = "gp2"
    volume_size = "5"
  }

  tags {
    "Name" = "sinatra-web"
  }
}

output "instance_ip" {
  value = "${aws_instance.web.public_ip}"
}
