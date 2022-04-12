##############################################################################################################
#
# Fortinet
# Infrastructure As Code Demo
# GitHub Actions - Terraform Cloud
# Platform: Azure
#
##############################################################################################################
#
# Deployment of the FortiGate Next-Generation Firewall
#
##############################################################################################################

resource "random_id" "fgt_storage_account" {
  byte_length = 8
}

resource "azurerm_storage_account" "fgtsa" {
  name                     = "tfsta${lower(random_id.fgt_storage_account.hex)}"
  resource_group_name      = azurerm_resource_group.resourcegroup.name
  location                 = azurerm_resource_group.resourcegroup.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_public_ip" "fgtpip" {
  name                = "${var.PREFIX}-FGT-PIP"
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.resourcegroup.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = format("%s-%s", lower(var.PREFIX), "fgt-pip")
}

resource "azurerm_network_security_group" "fgtnsg" {
  name                = "${var.PREFIX}-FGT-NSG"
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.resourcegroup.name
}

resource "azurerm_network_security_rule" "fgtnsgallowallout" {
  name                        = "AllowAllOutbound"
  resource_group_name         = azurerm_resource_group.resourcegroup.name
  network_security_group_name = azurerm_network_security_group.fgtnsg.name
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "fgtnsgallowallin" {
  name                        = "AllowAllInbound"
  resource_group_name         = azurerm_resource_group.resourcegroup.name
  network_security_group_name = azurerm_network_security_group.fgtnsg.name
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

resource "azurerm_network_interface" "fgtifcext" {
  name                          = "${var.PREFIX}-FGT-VM-IFC-EXT"
  location                      = azurerm_resource_group.resourcegroup.location
  resource_group_name           = azurerm_resource_group.resourcegroup.name
  enable_ip_forwarding          = true
  enable_accelerated_networking = var.FGT_ACCELERATED_NETWORKING

  ip_configuration {
    name                          = "interface1"
    subnet_id                     = data.tfe_outputs.network.values.vnet_subnet_id[0]
    private_ip_address_allocation = "Static"
    private_ip_address            = var.fgt_ipaddress[0]
    public_ip_address_id          = azurerm_public_ip.fgtpip.id
  }
}

resource "azurerm_network_interface_security_group_association" "fgtifcmgmtnsg" {
  network_interface_id      = azurerm_network_interface.fgtifcext.id
  network_security_group_id = azurerm_network_security_group.fgtnsg.id
}


resource "azurerm_network_interface" "fgtifcint" {
  name                          = "${var.PREFIX}-FGT-VM-IFC-INT"
  location                      = azurerm_resource_group.resourcegroup.location
  resource_group_name           = azurerm_resource_group.resourcegroup.name
  enable_ip_forwarding          = true
  enable_accelerated_networking = var.FGT_ACCELERATED_NETWORKING

  ip_configuration {
    name                          = "interface1"
    subnet_id                     = data.tfe_outputs.network.values.vnet_subnet_id[1]
    private_ip_address_allocation = "Static"
    private_ip_address            = var.fgt_ipaddress[1]
  }
}

resource "azurerm_network_interface_security_group_association" "fgtifcintnsg" {
  network_interface_id      = azurerm_network_interface.fgtifcint.id
  network_security_group_id = azurerm_network_security_group.fgtnsg.id
}

resource "azurerm_linux_virtual_machine" "fgtvm" {
  name                  = "${var.PREFIX}-FGT-VM"
  location              = azurerm_resource_group.resourcegroup.location
  resource_group_name   = azurerm_resource_group.resourcegroup.name
  network_interface_ids = [azurerm_network_interface.fgtifcext.id, azurerm_network_interface.fgtifcint.id]
  size                  = var.fgt_vmsize

  identity {
    type = "SystemAssigned"
  }

  source_image_reference {
    publisher = "fortinet"
    offer     = "fortinet_fortigate-vm_v5"
    sku       = var.FGT_IMAGE_SKU
    version   = var.FGT_VERSION
  }

  plan {
    name      = var.FGT_IMAGE_SKU
    product   = "fortinet_fortigate-vm_v5"
    publisher = "fortinet"
  }

  os_disk {
    name                 = "${var.PREFIX}-FGT-VM-OSDISK"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  admin_username                  = var.USERNAME
  admin_password                  = var.PASSWORD
  disable_password_authentication = false
  custom_data                     = base64encode(data.template_file.fgt_custom_data.rendered)

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.fgtsa.primary_blob_endpoint
  }

  tags = var.fortinet_tags
}

data "template_file" "fgt_custom_data" {
  template = file("${path.module}/customdata-fgt.tpl")

  vars = {
    fgt_vm_name         = "${var.PREFIX}-FGT-VM"
    fgt_license_file    = var.FGT_BYOL_LICENSE_FILE
    fgt_license_flexvm  = data.external.flexvm.result.vmToken
    fgt_username        = var.USERNAME
    fgt_password        = var.PASSWORD
    fgt_ssh_public_key  = var.FGT_SSH_PUBLIC_KEY_FILE
    fgt_external_ipaddr = var.fgt_ipaddress[0]
    fgt_external_mask   = split("/", data.tfe_outputs.network.values.vnet_subnet[0])[1]
    fgt_external_gw     = var.gateway_ipaddress["1"]
    fgt_internal_ipaddr = var.fgt_ipaddress[1]
    fgt_internal_mask   = split("/", data.tfe_outputs.network.values.vnet_subnet[1])[1]
    fgt_internal_gw     = var.gateway_ipaddress["2"]
    vnet_network        = data.tfe_outputs.network.values.vnet
  }
}

data "azurerm_public_ip" "fgtpip" {
  name                = azurerm_public_ip.fgtpip.name
  resource_group_name = azurerm_resource_group.resourcegroup.name
  depends_on          = [azurerm_linux_virtual_machine.fgtvm]
}

##############################################################################################################
# Role Assignment for Managed Identity
##############################################################################################################

data "azurerm_subscription" "current" {}

resource "azurerm_role_assignment" "rolerg" {
  scope                = azurerm_resource_group.resourcegroup.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.fgtvm.identity[0].principal_id
}

resource "azurerm_role_assignment" "rolesub" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.fgtvm.identity[0].principal_id
}

##############################################################################################################
