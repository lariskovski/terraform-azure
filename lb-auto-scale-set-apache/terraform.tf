terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.56.0"
    }
  }

  # Needs previous Storage Account setup
  # backend "azurerm" {
  #   resource_group_name   = ""
  #   storage_account_name  = ""
  #   container_name        = ""
  #   key                   = ""
  # }
}

# Configure the Microsoft Azure Provider
provider azurerm {
      features {}
      subscription_id = "${var.subscription_id}"
      client_id       = "${var.client_id}"
      client_secret   = "${var.client_secret}"
      tenant_id       = "${var.tenant_id}"
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "rg" {
  name      = var.rg_name
  location  = var.region
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
    name                = "${var.project_name}-net"
    address_space       = ["10.0.0.0/16"]
    location            = var.region
    resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "subnet" {
    name                 = "${var.project_name}-sub"
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "pip" {
    name                         = "${var.project_name}-pip"
    location                     = var.region
    resource_group_name          = azurerm_resource_group.rg.name
    allocation_method            = "Static"
}

resource "azurerm_lb" "lb" {
    name                = "${var.project_name}-lb"
    location            = "${azurerm_resource_group.rg.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"

    frontend_ip_configuration {
      name                 = "PublicIPAddress"
      public_ip_address_id = azurerm_public_ip.pip.id
    }
}

resource "azurerm_lb_backend_address_pool" "addrpool" {
  # resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id = azurerm_lb.lb.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_rule" "lbrule" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.addrpool.id}"
}

# # Create network interface
# resource "azurerm_network_interface" "nic" {
#     name                      = "${var.project_name}-nic"
#     location                  = azurerm_resource_group.rg.location
#     resource_group_name       = azurerm_resource_group.rg.name

#     ip_configuration {
#         name                          = "scale-set-nic"
#         subnet_id                     = azurerm_subnet.subnet.id
#         private_ip_address_allocation = "Dynamic"
#     }
# }

# Create Network Security Group and rule
resource "azurerm_network_security_group" "secgroup" {
    name                = "secgroup"
    location            = var.region
    resource_group_name = azurerm_resource_group.rg.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
    security_rule {
        name                       = "Apache"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}


# # Connect the security group to the network interface
# resource "azurerm_network_interface_security_group_association" "example" {
#     network_interface_id      = azurerm_network_interface.nic.id
#     network_security_group_id = azurerm_network_security_group.secgroup.id
# }

# Create (and display on output) an SSH key
# resource "tls_private_key" "sshkey" {
#   algorithm = "RSA"
#   rsa_bits = 4096
# }
# output "tls_private_key" { value = tls_private_key.sshkey.private_key_pem }

#############################
# Cloud config configuration#
#############################
data "template_file" "cloudconfig" {
  template = file("cloud-init.txt")
}

data "template_cloudinit_config" "config" {
  # gzip          = true
  base64_encode  = true

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.cloudconfig.rendered
  }
}


# Create virtual machine scale set
resource "azurerm_linux_virtual_machine_scale_set" "vms" {
    name                  = "${var.project_name}"
    location              = azurerm_resource_group.rg.location
    resource_group_name   = azurerm_resource_group.rg.name
    sku                   = "Standard_F2"

    admin_username        = "${var.ssh_key_username}"
    disable_password_authentication = true
    instances             = 2

    custom_data           = data.template_cloudinit_config.config.rendered

    admin_ssh_key {
        username       = "${var.ssh_key_username}"
        public_key     = file(var.ssh_key_pub)
        # public_key     = tls_private_key.sshkey.public_key_openssh
    }

    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
        # disk_size_gb = 30
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    network_interface {
      name        = "public-nic"
      primary     = true
      network_security_group_id = "${azurerm_network_security_group.secgroup.id}"

      ip_configuration {
        name      = "scale-vm-ips"
        primary   = true
        subnet_id = "${azurerm_subnet.subnet.id}"
        load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.addrpool.id}"]
        
        public_ip_address{
          name    = "testing-public-ip"
        }
      }
    }

  # provisioner "remote-exec" {
  #   inline = ["sudo apt update && sudo apt install apache2 -y"]

  #   connection {
  #     host        = "${self.public_ip_address}"
  #     type        = "ssh"
  #     user        = "${var.ssh_key_username}"
  #     private_key = "${file(var.ssh_key_private)}"
  #   }
  # }
}


# resource "azurerm_storage_account" "sa" {
#   name                     = "${var.project_name}static"
#   resource_group_name      = azurerm_resource_group.rg.name
#   location                 = azurerm_resource_group.rg.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
# }


