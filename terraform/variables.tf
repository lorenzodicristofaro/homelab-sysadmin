variable "pve_endpoint" {
  type = string
}
variable "pve_api_token" {
  type      = string
  sensitive = true
}
variable "ssh_pubkey_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}
