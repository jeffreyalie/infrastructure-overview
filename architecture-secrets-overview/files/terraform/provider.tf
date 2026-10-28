# --- AWS Provider ---
provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtn..."

  assume_role {
    role_arn     = "arn:aws:iam::123456789012:role/TerraformDeployRole"
    session_name = "terraform-gitea-ci"
  }

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

# --- vSphere / vCenter Provider ---
provider "vsphere" {
  vcenter_server       = "vcenter.corp.local"
  user                 = "administrator@vsphere.local"
  password             = var.vsphere_password
  allow_unverified_ssl = true
}

# --- LXD Provider (YOUR homelab) ---
provider "lxd" {
  accept_remote_certificate    = true
  generate_client_certificates = true

  remote {
    name    = "lxd-host"
    address = "https://${var.lxd_address}:8443"
    default = true
  }
}