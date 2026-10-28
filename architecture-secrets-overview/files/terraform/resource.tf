# --- AWS EC2 Instance ---
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = data.aws_vpc.main.id
  key_name      = "ansible-key"

  user_data = templatefile("${path.module}/cloud-init/user-data.yaml", {
    vm_hostname            = var.vm_name
    ansible_ssh_public_key = var.ansible_ssh_public_key
  })

  tags = {
    Name        = var.vm_name
    Environment = var.environment
  }
}

# --- vSphere Virtual Machine ---
resource "vsphere_virtual_machine" "vm" {
  name             = var.vm_name
  datacenter_id    = data.vsphere_datacenter.dc.id
  datastore_id     = data.vsphere_datastore.ds.id
  num_cpus         = var.cpu_count
  memory           = var.memory_size
  guest_id         = data.vsphere_virtual_machine.template.guest_id

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }

  network_interface {
    network_id = data.vsphere_network.net.id
  }

  disk {
    label = "disk0"
    size  = var.disk_size
  }

  extra_config = {
    "guestinfo.userdata"          = base64encode(templatefile("${path.module}/cloud-init/user-data.yaml", {
      vm_hostname            = var.vm_name
      ansible_ssh_public_key = var.ansible_ssh_public_key
    }))
    "guestinfo.userdata.encoding" = "base64"
  }
}

# --- LXD Virtual Machine (YOUR homelab) ---
locals {
  instance_name = "${var.environment}-${var.os_type}-${var.vm_name}"

  user_data = templatefile("${path.module}/cloud-init/user-data.yaml", {
    vm_hostname            = local.instance_name
    ansible_ssh_public_key = var.ansible_ssh_public_key
  })
}

resource "lxd_instance" "ubuntu_vm" {
  name    = local.instance_name
  image   = var.image
  type    = "virtual-machine"
  running = true

  config = {
    "user.user-data"  = local.user_data
    "boot.autostart"  = "true"
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = var.network
    }
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      pool = var.storage_pool
      path = "/"
      size = var.disk_size
    }
  }

  limits = {
    cpu    = tostring(var.cpu_count)
    memory = var.memory_size
  }
}