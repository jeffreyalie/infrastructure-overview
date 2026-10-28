# =============================================================================
# data {} block — READ existing infrastructure, don't create it.
# Fetches read-only information from the provider to use in your resources.
# Think of it as: resource{} = create/manage, data{} = look up/reference.
# =============================================================================

# --- AWS: Lookup existing VPC ---
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["main-vpc"]
  }
}

# --- AWS: Lookup latest Ubuntu 24.04 AMI ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]    # Canonical's AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# --- AWS: Lookup existing IAM role ---
data "aws_iam_role" "terraform" {
  name = "TerraformDeployRole"
}

# --- AWS: Lookup existing S3 bucket ---
data "aws_s3_bucket" "state" {
  bucket = "my-terraform-state"
}

# --- vSphere: Lookup Datacenter ---
data "vsphere_datacenter" "dc" {
  name = "HomeLab-DC"
}

# --- vSphere: Lookup Datastore ---
data "vsphere_datastore" "ds" {
  name          = "datastore1"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# --- vSphere: Lookup Network ---
data "vsphere_network" "vm_network" {
  name          = "VM Network"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# --- vSphere: Lookup VM Template (used to clone new VMs from) ---
data "vsphere_virtual_machine" "template" {
  name          = "ubuntu-24-04-template"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# --- LXD: Lookup existing LXD instance ---
data "lxd_instance" "existing_vm" {
  name = "prod-ubuntu-vm-prod01"
}

# --- Template File: render cloud-init / config files (any provider) ---
data "template_file" "user_data" {
  template = file("${path.module}/cloud-init/user-data.yaml")
  vars = {
    vm_hostname            = var.vm_name
    ansible_ssh_public_key = var.ansible_ssh_public_key
  }
}

# --- Referencing data sources in resources ---
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id        # ← from data lookup above
  instance_type = "t3.micro"
  subnet_id     = data.aws_vpc.main.id          # ← from data lookup above
}