# Primeiro IPv4 que não é loopback, como o agente reporta. Nulo até o agente
# responder.
output "ipv4" {
  value = try([
    for ip in flatten(proxmox_virtual_environment_vm.this.ipv4_addresses) : ip
    if ip != "127.0.0.1"
  ][0], null)
}

output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}
