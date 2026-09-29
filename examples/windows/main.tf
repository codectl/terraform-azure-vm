module "naming" {
  source  = "codectl/naming/azure"
  version = "~> 0.1"

  suffix = ["demo", "dev"]
}

module "regions" {
  source  = "codectl/locations/azure"
  version = "~> 1.0"

  location = {
    primary = "westeurope"
  }
}

module "rg" {
  source  = "codectl/rg/azure"
  version = "~> 1.0"

  groups = {
    demo = {
      name     = module.naming.resource_group.name_unique
      location = module.regions.location.primary.name
    }
  }
}

module "network" {
  source  = "codectl/vnet/azure"
  version = "~> 1.0"


  vnet = {
    name                = module.naming.virtual_network.name
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
    address_space       = ["10.18.0.0/16"]

    subnets = {
      int = {
        address_prefixes       = ["10.18.1.0/24"]
        network_security_group = {}
      }
    }
  }
}

module "kv" {
  source  = "codectl/kv/azure"
  version = "~> 1.0"


  vault = {
    name                = module.naming.key_vault.name_unique
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
    secrets = {
      random_string = {
        vm1 = {
          length  = 24
          special = false
        }
      }
    }
  }
}

module "vm" {
  source  = "codectl/vm/azure"
  version = "~> 1.0"


  virtual_machine = {
    type     = "windows"
    size     = "Standard_D2s_v3"
    username = "adminuser"
    os_disk = {
      storage_account_type = "Standard_LRS"
    }
    name                = module.naming.windows_virtual_machine.name_unique
    resource_group_name = module.rg.groups.demo.name
    location            = module.rg.groups.demo.location
    password            = module.kv.secrets.vm1.value

    source_image_reference = {
      offer     = "WindowsServer"
      publisher = "MicrosoftWindowsServer"
      sku       = "2022-Datacenter"
    }

    interfaces = {
      int = {
        ip_configurations = {
          config1 = {
            subnet_id = module.network.subnets.int.id
            primary   = true
          }
        }
      }
    }
  }
}
