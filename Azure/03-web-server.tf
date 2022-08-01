##############################################################################################################
#
# Fortinet
# Infrastructure As Code Demo
# GitHub Actions - Terraform Cloud
#
##############################################################################################################
#
# Deploy lnx-web server with Docker container
#
##############################################################################################################

resource "azurerm_network_interface" "lnx-webifc" {
  name                 = "${var.PREFIX}-lnx-web-VM-ifc"
  location             = var.LOCATION
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  enable_ip_forwarding = false

  ip_configuration {
    name                          = "interface1"
    subnet_id                     = azurerm_subnet.subnet3.id
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_virtual_machine" "lnx-webvm" {
  name                  = "${var.PREFIX}-lnx-web-VM2"
  location              = var.LOCATION
  resource_group_name   = azurerm_resource_group.resourcegroup.name
  network_interface_ids = [azurerm_network_interface.lnx-webifc.id]
  vm_size               = "Standard_B1s"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.PREFIX}-lnx-web-VM-OSDISK"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${var.PREFIX}-lnx-web-VM"
    admin_username = var.USERNAME
    admin_password = var.PASSWORD
    custom_data    = data.template_file.lnx-web_custom_data.rendered
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = var.backend_tags
}

data "template_file" "lnx-web_custom_data" {
  template = file("${path.module}/customdata-lnx.tpl")

  vars = {
  }
}
