# Firewall da Hetzner: fica fora da VPS, então barra também as portas que o
# Docker publica por cima do UFW (8000 do painel, 6001/6002 do realtime).
# Com regras de entrada, o resto é descartado; saída livre; stateful.
# Sem 22 e sem 8000: SSH e painel só pela tailnet.
resource "hcloud_firewall" "coolify" {
  name = var.name

  labels = {
    env = "lab"
  }

  # Proxy do Coolify (Traefik): os sites publicados.
  rule {
    description = "HTTP"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "HTTPS"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # Conexão direta do Tailscale; sem ela os pares caem no relay (DERP).
  rule {
    description = "Tailscale direto"
    direction   = "in"
    protocol    = "udp"
    port        = "41641"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "ICMP (ping, path MTU)"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}
