# IP fixo, calculado do VMID: conhecido já no plan, sem esperar o agente.
output "ipv4" {
  value = local.ipv4
}

output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}
