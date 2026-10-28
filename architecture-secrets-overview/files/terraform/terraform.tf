# --- Terraform Block ---
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.6"
    }
    lxd = {
      source  = "terraform-lxd/lxd"
      version = "~> 2.0"
    }
  }

  # --- S3 Backend (MinIO homelab) ---
  backend "s3" {
    endpoint                    = "http://10.248.42.22:9000"
    bucket                      = "terraform-state"
    key                         = "state/dev/dev01/terraform.tfstate"
    region                      = "us-east-1"
    access_key                  = "minioadmin"
    secret_key                  = "minioadmin"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    force_path_style            = true
  }

  # --- S3 Backend (Real AWS) ---
  backend "s3" {
    bucket     = "my-terraform-state"
    key        = "state/prod/terraform.tfstate"
    region     = "us-east-1"
    access_key = "AKIAIOSFODNN7EXAMPLE"
    secret_key = "wJalrXUtn..."
  }

  # --- HTTP Backend (Gitea) ---
  # backend "http" {
  #   address        = "http://gitea.local/<user>/<repo>/terraform-state/<name>"
  #   lock_address   = "http://gitea.local/<user>/<repo>/terraform-state/<name>/lock"
  #   unlock_address = "http://gitea.local/<user>/<repo>/terraform-state/<name>/lock"
  #   username       = "gitea-username"
  #   password       = "gitea-token"
  #   lock_method    = "POST"
  #   unlock_method  = "DELETE"
  # }
}