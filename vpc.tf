provider "aws" {
         access_key = "${var.access_key}"
         secret_key = "${var.secret_key}"
         region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "10.0.0.0_US_EAST"
  }
}

resource "aws_subnet" "main_private" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1c"
  tags = {
    Name = "10.0.2.0_US_EAST_1c_PRI"
  }
}

resource "aws_subnet" "main_public" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "10.0.1.0_US_EAST_1b_PUB"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "main"
  }
}

resource "aws_eip" "lb" {
}

resource "aws_nat_gateway" "default" {
  allocation_id = "${aws_eip.lb.id}"
  subnet_id = "${aws_subnet.main_public.id}"
}

resource "aws_route_table" "main_private_route_main" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.default.id}"
  }

  tags = {
    Name = "10.0.0.0_MAIN_RTB"
  }
}

resource "aws_route_table_association" "main_rtb" {
  subnet_id      = "${aws_subnet.main_private.id}"
  route_table_id = "${aws_route_table.main_private_route_main.id}"
}

resource "aws_route_table" "main_pubic_route_custom" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags = {
    Name = "10.0.0.0_CUSTOM_RTB"
  }
}

resource "aws_route_table_association" "custom_rtb" {
  subnet_id      = "${aws_subnet.main_public.id}"
  route_table_id = "${aws_route_table.main_pubic_route_custom.id}"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "ssh-anywhere" {
  name        = "ssh-anywhere"
  description = "Allow all inbound ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ssh-anywhere"
  }
}

resource "aws_instance" "bastion" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.main_public.id}"
  key_name = "aws_virginia"
  security_groups = [
    "${aws_security_group.ssh-anywhere.name}"
  ]
  associate_public_ip_address = true
  tags = {
    Name = "bastion"
  }
}

resource "aws_instance" "private" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.main_private.id}"
  key_name = "aws_virginia"
  tags = {
    Name = "private"
  }
}