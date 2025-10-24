provider "aws" {
  region = var.aws_region
}

# --- VPC ---
resource "aws_vpc" "aap_vpc" {
  cidr_block = "10.10.0.0/16"
  tags       = { Name = "AAP_VPC" }
}

# --- Subnet ---
resource "aws_subnet" "aap_subnet" {
  vpc_id                   = aws_vpc.aap_vpc.id
  cidr_block               = "10.10.1.0/24"
  availability_zone        = "${var.aws_region}a"
  map_public_ip_on_launch  = true  # <-- ensures public IPs
  tags                     = { Name = "AAP_Subnet" }
}

# --- Security Group ---
resource "aws_security_group" "aap_sg" {
  name        = "AAP_SG"
  description = "AAP lab security group"
  vpc_id      = aws_vpc.aap_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.56.106/32"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.aap_vpc.cidr_block]
  }

  ingress {
    from_port   = 1
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.aap_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "AAP_SG" }
}

# --- Key Pair ---
resource "tls_private_key" "aap_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "aap_keypair" {
  key_name   = "aap-key"
  public_key = tls_private_key.aap_key.public_key_openssh
}

resource "local_file" "aap_key_pem" {
  content         = tls_private_key.aap_key.private_key_pem
  filename        = "${path.module}/key.pem"
  file_permission = "0600"
}

# --- EC2 Instances ---
locals {
  instances = {
    controller01 = { type = "t3.medium", volume = 40 }
    hub01        = { type = "t3.small",  volume = 20 }
    exec01       = { type = "t3.small",  volume = 20 }
    db01         = { type = "t3.small",  volume = 30 }
  }
}

resource "aws_instance" "instances" {
  for_each                 = local.instances
  ami                       = var.ami_rhel9
  instance_type             = each.value.type
  subnet_id                 = aws_subnet.aap_subnet.id
  key_name                  = aws_key_pair.aap_keypair.key_name
  vpc_security_group_ids     = [aws_security_group.aap_sg.id]
  associate_public_ip_address = true  # <-- ensures public IP

  root_block_device {
    volume_size = each.value.volume
    volume_type = "gp3"
  }

  tags = { Name = "${each.key}.techroute.io" }
}

