# ==============================================================================
# AWS VoIP Lab - Terraform Variables
# ==============================================================================

# ------------------------------------------------------------------------------
# AWS Configuration
# ------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "voip-lab"
}

# ------------------------------------------------------------------------------
# Network Configuration
# ------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.2.0.0/24"
}

# ------------------------------------------------------------------------------
# Compute Configuration
# ------------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type (t2.micro for free tier)"
  type        = string
  default     = "t2.micro"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 instance access"
  type        = string
}

# ------------------------------------------------------------------------------
# Infrastructure IP Addresses
# ------------------------------------------------------------------------------

variable "my_ip" {
  description = "Azure ops hub IP for management access"
  type        = string
}

variable "home_ip" {
  description = "Your home IP address (optional)"
  type        = string
  default     = ""
}

variable "oracle_vm1_ip" {
  description = "Oracle VM1 (signaling) public IP"
  type        = string
  default     = "144.24.1.61/32"
}

variable "oracle_vm2_ip" {
  description = "Oracle VM2 (media) public IP"
  type        = string
  default     = "141.148.155.33/32"
}

variable "gcp_ip" {
  description = "GCP VM public IP"
  type        = string
  default     = "34.44.206.214/32"
}

variable "gcp_monitoring_ip" {
  description = "GCP Prometheus IP for metrics collection"
  type        = string
  default     = "34.44.206.214/32"
}

variable "azure_ip" {
  description = "Azure ops hub public IP"
  type        = string
  default     = "4.235.114.198/32"
}

# ------------------------------------------------------------------------------
# IP Lists for Security Groups
# ------------------------------------------------------------------------------

variable "all_voip_infrastructure_ips" {
  description = "All VoIP lab infrastructure IPs (for SSH access)"
  type        = list(string)
  default     = []
}

variable "allowed_sip_ips" {
  description = "IPs allowed to send SIP traffic"
  type        = list(string)
  default     = []
}

# ------------------------------------------------------------------------------
# Prometheus Allowed IP's  
# ------------------------------------------------------------------------------

variable "prometheus_allowed_ips" {
  description = "IPs allowed to scrape Prometheus exporters"
  type        = list(string)
  default     = [
    "34.44.206.214/32",  # GCP Prometheus
    "4.235.114.198/32"   # Azure management
  ]
}
