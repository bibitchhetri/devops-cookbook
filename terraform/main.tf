terraform {
  required_providers {
    multipass = {
      source  = "larstobi/multipass"
      version = "~> 1.0"
    }
  }
}

provider "multipass" {}

resource "multipass_instance" "devops_vm" {
  name   = "devops-vm"
  cpus   = 1
  memory = "1G"
  disk   = "5G"
}
