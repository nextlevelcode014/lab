output "ip" {
  value = module.coolify.ipv4
}

output "painel" {
  value = "http://${module.coolify.ipv4}:8000"
}
