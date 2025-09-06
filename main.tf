provider "azurerm" {
  features {
  }
subscription_id = var.F-SubscriptionID
}

#variables
variable "A-location" {
    description = "Location of the resources"
    #default     = "eastus"
}

variable "B-resource_group_name" {
    description = "Name of the resource group to create"
}

variable "C-home_public_ip" {
    description = "Your home public ip address"
}

variable "D-username" {
    description = "Username for Virtual Machines"
    #default     = "azureuser"
}

variable "E-password" {
    description = "Password for Virtual Machines"
    sensitive = true
}

variable "F-SubscriptionID" {
  description = "Subscription ID to use"  
}

resource "azurerm_resource_group" "RG" {
  location = var.A-location
  name     = var.B-resource_group_name
  provisioner "local-exec" {
    command = "az vm image terms accept --urn cisco:cisco-c8000v-byol:17_13_01a-byol:latest"
  }
}

#logic app to self destruct resourcegroup after 24hrs
data "azurerm_subscription" "sub" {
}

resource "azurerm_logic_app_workflow" "workflow1" {
  location = azurerm_resource_group.RG.location
  name     = "labdelete"
  resource_group_name = azurerm_resource_group.RG.name
  identity {
    type = "SystemAssigned"
  }
  depends_on = [
    azurerm_resource_group.RG,
  ]
}
resource "azurerm_role_assignment" "contrib1" {
  scope = azurerm_resource_group.RG.id
  role_definition_name = "Contributor"
  principal_id  = azurerm_logic_app_workflow.workflow1.identity[0].principal_id
  depends_on = [azurerm_logic_app_workflow.workflow1]
}

resource "azurerm_resource_group_template_deployment" "apiconnections" {
  name                = "group-deploy"
  resource_group_name = azurerm_resource_group.RG.name
  deployment_mode     = "Incremental"
  template_content = <<TEMPLATE
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {},
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.Web/connections",
            "apiVersion": "2016-06-01",
            "name": "arm-1",
            "location": "${azurerm_resource_group.RG.location}",
            "kind": "V1",
            "properties": {
                "displayName": "labdeleteconn1",
                "authenticatedUser": {},
                "statuses": [
                    {
                        "status": "Ready"
                    }
                ],
                "connectionState": "Enabled",
                "customParameterValues": {},
                "alternativeParameterValues": {},
                "parameterValueType": "Alternative",
                "createdTime": "2023-05-21T23:07:20.1346918Z",
                "changedTime": "2023-05-21T23:07:20.1346918Z",
                "api": {
                    "name": "arm",
                    "displayName": "Azure Resource Manager",
                    "description": "Azure Resource Manager exposes the APIs to manage all of your Azure resources.",
                    "iconUri": "https://connectoricons-prod.azureedge.net/laborbol/fixes/path-traversal/1.0.1552.2695/arm/icon.png",
                    "brandColor": "#003056",
                    "id": "/subscriptions/${data.azurerm_subscription.sub.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.RG.location}/managedApis/arm",
                    "type": "Microsoft.Web/locations/managedApis"
                },
                "testLinks": []
            }
        },
        {
            "type": "Microsoft.Logic/workflows",
            "apiVersion": "2017-07-01",
            "name": "labdelete",
            "location": "${azurerm_resource_group.RG.location}",
            "dependsOn": [
                "[resourceId('Microsoft.Web/connections', 'arm-1')]"
            ],
            "identity": {
                "type": "SystemAssigned"
            },
            "properties": {
                "state": "Enabled",
                "definition": {
                    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
                    "contentVersion": "1.0.0.0",
                    "parameters": {
                        "$connections": {
                            "defaultValue": {},
                            "type": "Object"
                        }
                    },
                    "triggers": {
                        "Recurrence": {
                            "recurrence": {
                                "frequency": "Minute",
                                "interval": 3,
                                "startTime": "${timeadd(timestamp(),"24h")}"
                            },
                            "evaluatedRecurrence": {
                                "frequency": "Minute",
                                "interval": 3,
                                "startTime": "${timeadd(timestamp(),"24h")}"
                            },
                            "type": "Recurrence"
                        }
                    },
                    "actions": {
                        "Delete_a_resource_group": {
                            "runAfter": {},
                            "type": "ApiConnection",
                            "inputs": {
                                "host": {
                                    "connection": {
                                        "name": "@parameters('$connections')['arm']['connectionId']"
                                    }
                                },
                                "method": "delete",
                                "path": "/subscriptions/@{encodeURIComponent('${data.azurerm_subscription.sub.subscription_id}')}/resourcegroups/@{encodeURIComponent('${azurerm_resource_group.RG.name}')}",
                                "queries": {
                                    "x-ms-api-version": "2016-06-01"
                                }
                            }
                        }
                    },
                    "outputs": {}
                },
                "parameters": {
                    "$connections": {
                        "value": {
                            "arm": {
                                "connectionId": "[resourceId('Microsoft.Web/connections', 'arm-1')]",
                                "connectionName": "arm-1",
                                "connectionProperties": {
                                    "authentication": {
                                        "type": "ManagedServiceIdentity"
                                    }
                                },
                                "id": "/subscriptions/${data.azurerm_subscription.sub.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.RG.location}/managedApis/arm"
                            }
                        }
                    }
                }
            }
        }
    ]
}
TEMPLATE
}


#vwan and hub
resource "azurerm_virtual_wan" "vwan1" {
  name                = "vwan1"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
    timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_virtual_hub" "vhub1" {
  name                = "vhub1"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  virtual_wan_id      = azurerm_virtual_wan.vwan1.id
  address_prefix      = "10.0.0.0/16"
    timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}


resource "azurerm_route_map" "routemap1" {
  name           = "routemap-one"
  virtual_hub_id = azurerm_virtual_hub.vhub1.id

  rule {
    name                 = "rule1"
    next_step_if_matched = "Terminate"

    action {
      type = "Replace"

      parameter {
        route_prefix = ["192.168.0.0/16"]
      }
    }

    match_criterion {
      match_condition = "Equals"
      route_prefix    = ["192.168.0.0/24"]
    }
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  } 
   
}


resource "azurerm_route_map" "routemap2" {
  name           = "routemap-two"
  virtual_hub_id = azurerm_virtual_hub.vhub1.id

  rule {
    name                 = "rule2"
    next_step_if_matched = "Terminate"

    action {
      type = "Add"

      parameter {
        as_path = ["61234"]
      }
    }

    match_criterion {
      match_condition = "Equals"
      route_prefix    = ["10.250.0.0/16"]
    }
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
   
}

#spoke vnets
resource "azurerm_virtual_network" "spoke1-vnet" {
  address_space       = ["10.150.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "spoke1-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefixes     = ["10.150.0.0/24"]
    name                 = "default"
    security_group = azurerm_network_security_group.spokevnetNSG.id
  }
  subnet {
    address_prefixes     = ["10.150.1.0/24"]
    name                 = "GatewaySubnet" 
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_virtual_network" "spoke2-vnet" {
  address_space       = ["10.250.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "spoke2-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefixes     = ["10.250.0.0/24"]
    name                 = "default"
    security_group = azurerm_network_security_group.spokevnetNSG.id
  }
  subnet {
    address_prefixes     = ["10.250.1.0/24"]
    name                 = "GatewaySubnet" 
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_virtual_network" "spoke3-vnet" {
  address_space       = ["10.75.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "spoke3-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefixes     = ["10.75.0.0/24"]
    name                 = "default"
    security_group = azurerm_network_security_group.sshnsg.id
  }
  
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

#vnet connections to hub
resource "azurerm_virtual_hub_connection" "tospoke1" {
  name                      = "tospoke1"
  internet_security_enabled = true
  virtual_hub_id            = azurerm_virtual_hub.vhub1.id
  remote_virtual_network_id = azurerm_virtual_network.spoke1-vnet.id
}
resource "azurerm_virtual_hub_connection" "tospoke2" {
  name                      = "tospoke2"
  internet_security_enabled = true
  virtual_hub_id            = azurerm_virtual_hub.vhub1.id
  remote_virtual_network_id = azurerm_virtual_network.spoke2-vnet.id
  
  routing {
    associated_route_table_id = data.azurerm_virtual_hub_route_table.hubdefaultrt.id    
    outbound_route_map_id = azurerm_route_map.routemap1.id
  }
  
}
resource "azurerm_virtual_hub_connection" "tospoke3" {
  name                      = "tospoke3"
  internet_security_enabled = true
  virtual_hub_id            = azurerm_virtual_hub.vhub1.id
  remote_virtual_network_id = azurerm_virtual_network.spoke3-vnet.id
  
  routing {
    associated_route_table_id = data.azurerm_virtual_hub_route_table.hubdefaultrt.id    
    outbound_route_map_id = azurerm_route_map.routemap2.id
  }
  
}


#NSG
resource "azurerm_network_security_group" "spokevnetNSG" {
  location            = azurerm_resource_group.RG.location
  name                = "spoke-vnet-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "spokevnetnsgrule1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "3389"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockRDPInbound"
  network_security_group_name = "spoke-vnet-default-nsg"
  priority                    = 2711
  protocol                    = "Tcp"
  resource_group_name         = azurerm_network_security_group.spokevnetNSG.resource_group_name
  source_address_prefix       = var.C-home_public_ip
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}


resource "azurerm_network_security_group" "sshnsg" {
  location            = azurerm_resource_group.RG.location
  name                = "ssh-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "sshnsgrule1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "22"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockSSHInbound"
  network_security_group_name = "ssh-default-nsg"
  priority                    = 100
  protocol                    = "Tcp"
  resource_group_name         = azurerm_network_security_group.sshnsg.resource_group_name
  source_address_prefix       = var.C-home_public_ip
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

#default table
data "azurerm_virtual_hub_route_table" "hubdefaultrt" {
  name                = "defaultRouteTable"
  resource_group_name = azurerm_resource_group.RG.name
  virtual_hub_name    = azurerm_virtual_hub.vhub1.name
}

#Public ip's
resource "azurerm_public_ip" "spoke1vm-pip" {
  name                = "spoke1vm-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Static"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_public_ip" "spoke2vm-pip" {
  name                = "spoke2vm-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Static"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}


resource "azurerm_public_ip" "c8000-pip" {
  name                = "c8000-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Static"
  sku = "Standard"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

#route table for home access
resource "azurerm_route_table" "RT" {
  name                          = "to-home"
  location                      = azurerm_resource_group.RG.location
  resource_group_name           = azurerm_resource_group.RG.name
  

  route {
    name           = "tohome"
    address_prefix = "${var.C-home_public_ip}/32"
    next_hop_type  = "Internet"
    
  }
  
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
}
resource "azurerm_subnet_route_table_association" "onspoke1defaultsubnet" {
  subnet_id      = azurerm_virtual_network.spoke1-vnet.subnet.*.id[0]
  route_table_id = azurerm_route_table.RT.id
  timeouts {
    create = "2h"
    read = "2h"
    delete = "2h"
  }
}
resource "azurerm_subnet_route_table_association" "onspoke2defaultsubnet" {
  subnet_id      = azurerm_virtual_network.spoke2-vnet.subnet.*.id[0]
  route_table_id = azurerm_route_table.RT.id
  timeouts {
    create = "2h"
    read = "2h"
    delete = "2h"
  }
}
resource "azurerm_subnet_route_table_association" "onspoke3defaultsubnet" {
  subnet_id      = azurerm_virtual_network.spoke3-vnet.subnet.*.id[0]
  route_table_id = azurerm_route_table.RT.id
  timeouts {
    create = "2h"
    read = "2h"
    delete = "2h"
  }
}



#vnic's
resource "azurerm_network_interface" "spoke1vm-nic" {
  location            = azurerm_resource_group.RG.location
  name                = "spoke1vm-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.spoke1vm-pip.id
    subnet_id                     = azurerm_virtual_network.spoke1-vnet.subnet.*.id[0]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_interface" "spoke2vm-nic" {
  location            = azurerm_resource_group.RG.location
  name                = "spoke2vm-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.spoke2vm-pip.id
    subnet_id                     = azurerm_virtual_network.spoke2-vnet.subnet.*.id[0]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}


resource "azurerm_network_interface" "c8000-nic" {
  ip_forwarding_enabled = true
  location            = azurerm_resource_group.RG.location
  name                = "c8000-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.c8000-pip.id
    subnet_id                     = azurerm_virtual_network.spoke3-vnet.subnet.*.id[0]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

#VM's
resource "azurerm_windows_virtual_machine" "spoke1vm" {
  admin_password        = var.E-password
  admin_username        = var.D-username
  location              = azurerm_resource_group.RG.location
  name                  = "spoke1vm"
  network_interface_ids = [azurerm_network_interface.spoke1vm-nic.id]
  resource_group_name   = azurerm_resource_group.RG.name
  size                  = "Standard_B2ms"
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_virtual_machine_extension" "killspoke1vmfirewall" {
  auto_upgrade_minor_version = true
  name                       = "killspoke1vmfirewall"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  virtual_machine_id         = azurerm_windows_virtual_machine.spoke1vm.id
  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -command \"Set-NetFirewallProfile -Enabled False\""
    }
  SETTINGS
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_windows_virtual_machine" "spoke2vm" {
  admin_password        = var.E-password
  admin_username        = var.D-username
  location              = azurerm_resource_group.RG.location
  name                  = "spoke2vm"
  network_interface_ids = [azurerm_network_interface.spoke2vm-nic.id]
  resource_group_name   = azurerm_resource_group.RG.name
  size                  = "Standard_B2ms"
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_virtual_machine_extension" "killspoke2vmfirewall" {
  auto_upgrade_minor_version = true
  name                       = "killspokevmfirewall"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  virtual_machine_id         = azurerm_windows_virtual_machine.spoke2vm.id
  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -command \"Set-NetFirewallProfile -Enabled False\""
    }
  SETTINGS
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_virtual_hub_bgp_connection" "bgp1" {
  name           = "vhub-bgpconnection"
  virtual_hub_id = azurerm_virtual_hub.vhub1.id
  peer_asn       = 64444
  peer_ip        = "10.75.0.4"
  virtual_network_connection_id = azurerm_virtual_hub_connection.tospoke3.id
  
}

resource "azurerm_linux_virtual_machine" "hubc8000v" {
  admin_password                  = var.E-password
  admin_username                  = var.D-username
  disable_password_authentication = false
  location                        = azurerm_resource_group.RG.location
  name                            = "Hubc8000"
  network_interface_ids           = [azurerm_network_interface.c8000-nic.id]
  resource_group_name             = azurerm_resource_group.RG.name
  size                            = "Standard_D2_v2"
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  plan {
    name      = "17_13_01a-byol"
    product   = "cisco-c8000v-byol"
    publisher = "cisco"
  }
  source_image_reference {
    offer     = "cisco-c8000v-byol"
    publisher = "cisco"
    sku       = "17_13_01a-byol"
    version   = "latest"
  }
  custom_data = base64encode(local.c8000_custom_data)
}

# Locals Block for custom data
locals {
c8000_custom_data = <<CUSTOM_DATA
Section: IOS configuration


ip route 10.0.0.0 255.255.0.0 10.75.0.1

interface Loopback99
 ip address 192.168.0.1 255.255.255.0



router bgp 64444
 bgp log-neighbor-changes
 neighbor ${azurerm_virtual_hub.vhub1.virtual_router_ips[0]} remote-as 65515 
 neighbor ${azurerm_virtual_hub.vhub1.virtual_router_ips[0]} ebgp-multihop 10
 neighbor ${azurerm_virtual_hub.vhub1.virtual_router_ips[1]} remote-as 65515 
 neighbor ${azurerm_virtual_hub.vhub1.virtual_router_ips[1]} ebgp-multihop 10
 
 address-family ipv4
  network 192.168.0.0 mask 255.255.255.0  
  neighbor ${azurerm_virtual_hub.vhub1.virtual_router_ips[1]} activate
  neighbor ${azurerm_virtual_hub.vhub1.virtual_router_ips[1]} soft-reconfiguration inbound
  neighbor ${azurerm_virtual_hub.vhub1.virtual_router_ips[0]} activate
  neighbor ${azurerm_virtual_hub.vhub1.virtual_router_ips[0]} soft-reconfiguration inbound
 exit-address-family
  exit
CUSTOM_DATA  
}

