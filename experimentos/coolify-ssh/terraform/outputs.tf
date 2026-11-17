output "ipv4" {
  value = hcloud_server.coolify.ipv4_address
}

output "ssh" {
  value = "ssh lab@${hcloud_server.coolify.ipv4_address}"
}

output "tunel" {
  value = "ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -L 127.0.0.1:8000:127.0.0.1:8000 -L 127.0.0.1:6001:127.0.0.1:6001 -L 127.0.0.1:6002:127.0.0.1:6002 lab@${hcloud_server.coolify.ipv4_address}"
}

output "painel" {
  value = "http://127.0.0.1:8000"
}

output "dominio_teste" {
  value = "https://app.${hcloud_server.coolify.ipv4_address}.sslip.io"
}
