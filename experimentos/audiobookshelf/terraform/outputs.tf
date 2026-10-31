output "ip" {
  value = module.audiobookshelf.ipv4
}

output "painel" {
  value = "http://${module.audiobookshelf.ipv4}:13378"
}
