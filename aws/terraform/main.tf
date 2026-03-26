# ==============================================================================
# AWS VoIP Lab - Main Infrastructure
# ==============================================================================

# ------------------------------------------------------------------------------
# VPC (Virtual Private Cloud)
# ------------------------------------------------------------------------------

resource "aws_vpc" "voip_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ------------------------------------------------------------------------------
# Internet Gateway
# ------------------------------------------------------------------------------

resource "aws_internet_gateway" "voip_igw" {
  vpc_id = aws_vpc.voip_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ------------------------------------------------------------------------------
# Subnet
# ------------------------------------------------------------------------------

resource "aws_subnet" "voip_subnet" {
  vpc_id                  = aws_vpc.voip_vpc.id
  cidr_block              = var.vpc_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-subnet"
  }
}

# ------------------------------------------------------------------------------
# Route Table
# ------------------------------------------------------------------------------

resource "aws_route_table" "voip_rt" {
  vpc_id = aws_vpc.voip_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.voip_igw.id
  }

  tags = {
    Name = "${var.project_name}-rt"
  }
}

resource "aws_route_table_association" "voip_rta" {
  subnet_id      = aws_subnet.voip_subnet.id
  route_table_id = aws_route_table.voip_rt.id
}

# ------------------------------------------------------------------------------
# Security Group (Firewall Rules)
# ------------------------------------------------------------------------------

resource "aws_security_group" "voip_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for VoIP lab infrastructure"
  vpc_id      = aws_vpc.voip_vpc.id

  # SSH - From all VoIP infrastructure
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.all_voip_infrastructure_ips
    description = "SSH from all VoIP infrastructure"
  }

  # SIP UDP - From known VoIP infrastructure only
  ingress {
    from_port   = 5060
    to_port     = 5060
    protocol    = "udp"
    cidr_blocks = var.allowed_sip_ips
    description = "SIP UDP from known infrastructure"
  }

  # SIP TCP - From known VoIP infrastructure only
  ingress {
    from_port   = 5060
    to_port     = 5060
    protocol    = "tcp"
    cidr_blocks = var.allowed_sip_ips
    description = "SIP TCP from known infrastructure"
  }

  # RTP Range - Open for SIP clients (needed for dynamic endpoints)
  ingress {
    from_port   = 10000
    to_port     = 20000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "RTP media from anywhere"
  }
 # Prometheus Exporters - OpenSIPS
  ingress {
    from_port   = 9153
    to_port     = 9153
    protocol    = "tcp"
    cidr_blocks = var.prometheus_allowed_ips
    description = "OpenSIPS Exporter"
  }

  # Prometheus Exporters - FreeSWITCH
  ingress {
    from_port   = 9282
    to_port     = 9282
    protocol    = "tcp"
    cidr_blocks = var.prometheus_allowed_ips
    description = "FreeSWITCH Exporter"
  }

  # Prometheus Exporters - RTPEngine
  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = var.prometheus_allowed_ips
    description = "RTPEngine Exporter"
  }

  # Prometheus Node Exporter - From GCP monitoring only
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.gcp_monitoring_ip]
    description = "Node exporter from GCP Prometheus"
  }

  # Prometheus Redis Exporter - From GCP monitoring only
  ingress {
    from_port   = 9121
    to_port     = 9121
    protocol    = "tcp"
    cidr_blocks = [var.gcp_monitoring_ip]
    description = "Redis exporter from GCP Prometheus"
  }

  # WireGuard VPN - Open for VPN mesh
  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "WireGuard VPN for multi-cloud mesh"
  }

  # VPN Mesh Network - Internal communication
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.255.0.0/24"]
    description = "VPN mesh internal network"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# ------------------------------------------------------------------------------
# SSH Key Pair
# ------------------------------------------------------------------------------

resource "aws_key_pair" "voip_key" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key

  tags = {
    Name = "${var.project_name}-key"
  }
}

# ------------------------------------------------------------------------------
# AMI Data Source (Latest Ubuntu 22.04)
# ------------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ------------------------------------------------------------------------------
# EC2 Instance - Signaling VM
# ------------------------------------------------------------------------------

resource "aws_instance" "signaling" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.voip_key.key_name
  subnet_id              = aws_subnet.voip_subnet.id
  vpc_security_group_ids = [aws_security_group.voip_sg.id]
  private_ip             = "10.2.0.10"

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname aws-signaling
              EOF

  tags = {
    Name  = "${var.project_name}-signaling"
    Role  = "signaling"
    Cloud = "aws"
  }
}

# ------------------------------------------------------------------------------
# Elastic IP - Signaling VM
# ------------------------------------------------------------------------------

resource "aws_eip" "signaling_eip" {
  instance = aws_instance.signaling.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-signaling-eip"
  }
}

# ------------------------------------------------------------------------------
# EC2 Instance - Media VM
# ------------------------------------------------------------------------------

resource "aws_instance" "media" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.voip_key.key_name
  subnet_id              = aws_subnet.voip_subnet.id
  vpc_security_group_ids = [aws_security_group.voip_sg.id]
  private_ip             = "10.2.0.20"

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname aws-media
              EOF

  tags = {
    Name  = "${var.project_name}-media"
    Role  = "media"
    Cloud = "aws"
  }
}

# ------------------------------------------------------------------------------
# Elastic IP - Media VM
# ------------------------------------------------------------------------------

resource "aws_eip" "media_eip" {
  instance = aws_instance.media.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-media-eip"
  }
}
