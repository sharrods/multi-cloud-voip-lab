# ==============================================================================
# AWS VoIP Lab - Outputs
# ==============================================================================

# ------------------------------------------------------------------------------
# VM IP Addresses
# ------------------------------------------------------------------------------

output "signaling_public_ip" {
  description = "Public IP of signaling instance"
  value       = aws_eip.signaling_eip.public_ip
}

output "signaling_private_ip" {
  description = "Private IP of signaling instance"
  value       = aws_instance.signaling.private_ip
}

output "media_public_ip" {
  description = "Public IP of media instance"
  value       = aws_eip.media_eip.public_ip
}

output "media_private_ip" {
  description = "Private IP of media instance"
  value       = aws_instance.media.private_ip
}

# ------------------------------------------------------------------------------
# Network Resources
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.voip_vpc.id
}

output "subnet_id" {
  description = "Subnet ID"
  value       = aws_subnet.voip_subnet.id
}

output "security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.voip_sg.id
}

# ------------------------------------------------------------------------------
# Ansible Inventory
# ------------------------------------------------------------------------------

output "ansible_inventory" {
  description = "Ansible inventory snippet"
  value = <<-EOT
  
  aws-signaling:
    ansible_host: ${aws_eip.signaling_eip.public_ip}
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/multi-cloud-voip-lab/.ssh/multi-cloud-key
    private_ip: ${aws_instance.signaling.private_ip}
    cloud: aws
    role: signaling
    
  aws-media:
    ansible_host: ${aws_eip.media_eip.public_ip}
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/multi-cloud-voip-lab/.ssh/multi-cloud-key
    private_ip: ${aws_instance.media.private_ip}
    cloud: aws
    role: media
  EOT
}

# ------------------------------------------------------------------------------
# Next Steps
# ------------------------------------------------------------------------------

output "next_steps" {
  description = "Next steps after deployment"
  value = <<-EOT
  
  ================================================
  AWS Infrastructure Deployed Successfully!
  ================================================
  
  Signaling VM: ${aws_eip.signaling_eip.public_ip}
  Media VM:     ${aws_eip.media_eip.public_ip}
  
  SSH Access:
  -----------
  ssh -i ~/multi-cloud-voip-lab/.ssh/multi-cloud-key ubuntu@${aws_eip.signaling_eip.public_ip}
  ssh -i ~/multi-cloud-voip-lab/.ssh/multi-cloud-key ubuntu@${aws_eip.media_eip.public_ip}
  
  Next Steps:
  -----------
  1. Test SSH access to both VMs
  2. Create Ansible inventory
  3. Deploy VoIP stack with Ansible
  4. Add AWS targets to GCP Prometheus
  5. Configure WireGuard VPN mesh
  
  ================================================
  EOT
}
