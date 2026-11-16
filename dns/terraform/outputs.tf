# ==============================================================================
# Lab DNS - Outputs
# ==============================================================================

output "lab_sip_domain" {
  description = "SIP domain the phones point at (Poly: server address, port 0)"
  value       = local.lab_domain
}

output "srv_record" {
  description = "SRV record name and its values (priority weight port target)"
  value = {
    name    = aws_route53_record.sip_udp_srv.fqdn
    records = aws_route53_record.sip_udp_srv.records
  }
}

output "sip_server_a_records" {
  description = "Each SIP server host name and its IPv4 address"
  value = {
    for key, rec in aws_route53_record.sip_server_a :
    rec.fqdn => one(rec.records)
  }
}

output "test_commands" {
  description = "Run these to confirm the records are live"
  value = concat(
    ["dig SRV ${aws_route53_record.sip_udp_srv.fqdn} +short"],
    [for key, rec in aws_route53_record.sip_server_a : "dig A ${rec.fqdn} +short"]
  )
}
