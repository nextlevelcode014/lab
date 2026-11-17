# Defesa adicional do lab. O painel também é restrito no próprio host,
# para o procedimento de instalação não depender deste firewall.
resource "hcloud_firewall" "coolify" {
  name   = var.name
  labels = local.labels

  rule {
    description = "SSH dos administradores"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = var.ssh_source_cidrs
  }

  rule {
    description = "Sites HTTP"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Sites HTTPS"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "ICMP e path MTU"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}
