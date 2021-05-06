# output "tls_private_key" {
#     value = tls_private_key.sshkey.private_key_pem
# }
output "lb_public_ip" {
    value = azurerm_public_ip.pip.ip_address
}
