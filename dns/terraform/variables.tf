# ==============================================================================
# Lab DNS - Variables
# Values are defaults here on purpose: nothing is secret (the GCP IP is already
# public and DNS records are public by design), and *.tfvars is gitignored.
# ==============================================================================

variable "aws_region" {
  description = "AWS region for the provider. Route 53 is global; matches aws/terraform."
  type        = string
  default     = "us-east-1"
}

variable "root_domain" {
  description = "Domain registered in Route 53. Its hosted zone already exists and is only looked up, never managed here."
  type        = string
  default     = "sharrodskinner.com"
}

variable "lab_subdomain" {
  description = "Lab SIP domain label: voiplab -> voiplab.sharrodskinner.com"
  type        = string
  default     = "voiplab"
}

variable "record_ttl" {
  description = "TTL (time to live) in seconds for the lab records"
  type        = number
  default     = 300
}

variable "sip_servers" {
  description = <<-DESC
    SIP servers published in DNS. The map key becomes the host name under the
    lab domain. Each entry creates an A record and one line in the SRV record.
    priority: lower is tried first. weight: share between equal priorities.
  DESC
  type = map(object({
    ipv4     = string
    priority = number
    weight   = number
    port     = number
  }))
  default = {
    "opensips-gcp-uscentral1" = {
      ipv4     = "34.44.206.214"
      priority = 10
      weight   = 100
      port     = 5060
    }
  }
}
