# --- String Variable ---
variable "environment" {
  type        = string
  description = "Environment name (dev, prod)"
  default     = "dev"
}

# --- Number Variable ---
variable "cpu_count" {
  type        = number
  description = "Number of vCPUs"
  default     = 2
}

# --- Bool Variable ---
variable "enable_backups" {
  type        = bool
  description = "Enable automated backups"
  default     = true
}

# --- List Variable ---
variable "allowed_ips" {
  type        = list(string)
  description = "List of allowed IP addresses"
  default     = ["10.0.0.1", "10.0.0.2"]
}

# --- Map Variable ---
variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

# --- Object Variable ---
variable "vm_config" {
  type = object({
    cpu    = number
    memory = string
    disk   = string
  })
  default = {
    cpu    = 2
    memory = "2GiB"
    disk   = "10GiB"
  }
}

# --- Sensitive Variable (secrets — never put default values) ---
variable "ansible_ssh_public_key" {
  type      = string
  sensitive = true
}

# --- Variable with Validation ---
variable "environment" {
  type        = string
  description = "Environment name"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be dev or prod."
  }
}