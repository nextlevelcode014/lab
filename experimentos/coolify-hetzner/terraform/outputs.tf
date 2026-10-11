output "ipv4" {
  value = hcloud_server.coolify.ipv4_address
}

output "painel" {
  value = "http://${var.name}.${var.tailnet}:8000"
}

# Domínio curinga para o Coolify gerar os dos sites (Settings → Wildcard).
output "wildcard" {
  value = "http://${hcloud_server.coolify.ipv4_address}.sslip.io"
}
