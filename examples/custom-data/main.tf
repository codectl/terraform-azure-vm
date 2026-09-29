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
      tls_keys = {
        vm1 = {
          algorithm = "RSA"
          rsa_bits  = 2048
        }
      }
    }
  }
}

module "vm1" {
  source  = "codectl/vm/azure"
  version = "~> 1.0"


  virtual_machine = {
    type     = "linux"
    size     = "Standard_D2s_v3"
    username = "adminuser"
    os_disk = {
      storage_account_type = "Standard_LRS"
    }
    name                = module.naming.linux_virtual_machine.name_unique
    resource_group_name = module.rg.groups.demo.name
    location            = module.rg.groups.demo.location
    public_key          = module.kv.tls_public_keys.vm1.value

    source_image_reference = {
      offer     = "UbuntuServer"
      publisher = "Canonical"
      sku       = "18.04-LTS"
    }

    custom_data = trimspace(<<EOF
    I2Nsb3VkLWNvbmZpZwpwYWNrYWdlX3VwZ3JhZGU6IHRydWUKcGFja2FnZXM6CiAgLSBhcGFjaGUyCnJ1bmNtZDoKICAtIGVjaG8gIjxodG1sPjxib2R5PjxoMT5XZWxjb21lIHRvIE15IFdlYiBQYWdlPC9oMT48L2JvZHk+PC9odG1sPiIgPiAvdmFyL3d3dy9odG1sL2luZGV4Lmh0bWwK
    EOF
    )

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
