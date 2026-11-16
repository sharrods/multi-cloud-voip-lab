# ==============================================================================
# Lab DNS - Records
# Creates:
#   A   opensips-gcp-uscentral1.voiplab.sharrodskinner.com -> 34.44.206.214
#   SRV _sip._udp.voiplab.sharrodskinner.com
#         -> 10 100 5060 opensips-gcp-uscentral1.voiplab.sharrodskinner.com.
# Does NOT manage the sharrodskinner.com hosted zone - it is only looked up,
# so "terraform destroy" removes these lab records and nothing else.
# ==============================================================================

data "aws_route53_zone" "root" {
  name         = var.root_domain
  private_zone = false
}

locals {
  lab_domain = "${var.lab_subdomain}.${var.root_domain}"
}

resource "aws_route53_record" "sip_server_a" {
  for_each = var.sip_servers

  zone_id = data.aws_route53_zone.root.zone_id
  name    = "${each.key}.${local.lab_domain}"
  type    = "A"
  ttl     = var.record_ttl
  records = [each.value.ipv4]
}

# SRV value format: priority weight port target
# The target must end with a dot (a fully qualified name).
resource "aws_route53_record" "sip_udp_srv" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "_sip._udp.${local.lab_domain}"
  type    = "SRV"
  ttl     = var.record_ttl

  records = [
    for name, server in var.sip_servers :
    "${server.priority} ${server.weight} ${server.port} ${name}.${local.lab_domain}."
  ]

  depends_on = [aws_route53_record.sip_server_a]
}
