# OpenBao Full Working Setup

---

## Table of Contents

- [1. Required Directories](#1-required-directories)
- [2. Create CA (Self-Signed)](#2-create-ca-self-signed)
- [3. Create SAN Config](#3-create-san-config)
- [4. Generate Server Key](#4-generate-server-key)
- [5. Create CSR](#5-create-csr)
- [6. Sign Certificate](#6-sign-certificate)
- [7. Verify Files](#7-verify-files)
- [8. OpenBao Config](#8-openbao-config)
- [9. Fix systemd](#9-fix-systemd)
- [10. Start OpenBao](#10-start-openbao)
- [11. Set Local Access on Client Machine](#11-set-local-access-on-client-machine)
- [12. Initialize OpenBao](#12-initialize-openbao-only-once)
- [13. Unseal](#13-unseal)
- [14. Check Status](#14-check-status)
- [15. Access Web UI](#15-access-web-ui)
- [16. Fix Unknown Authority Error](#16-fix-unknown-authority-error-optional)
- [Phase 5 — AppRole Auth for Gitea Runner](#phase-5--approle-auth-for-gitea-runner)
- [Phase 6 — Update Gitea Org Secrets](#phase-6--update-gitea-org-secrets)
- [Phase 7 — Update GHA Workflows](#phase-7--update-gha-workflows)
- [Key Problems Fixed](#key-problems-fixed)
- [Final Mental Model](#final-mental-model)

---
Here's a complete single-node setup that matches existing workflow layout (Raft storage, self-signed TLS, AppRole, KV v2 at homelab/).

## 1. Install the package

```
# --- Resolve version ---
cd /tmp
apt install -y curl jq
VER=$(curl -fsS https://api.github.com/repos/openbao/openbao/releases/latest | jq -r '.tag_name' | sed 's/^v//')
VER=${VER:-2.7.1}
echo "Version: $VER"
```
```
# --- Download ---
curl -fLO "https://github.com/openbao/openbao/releases/download/v${VER}/openbao_${VER}_linux_amd64.deb"
ls -lh openbao_*_linux_amd64.deb
```
```
# --- Install ---
apt install -y ./openbao_${VER}_linux_amd64.deb
bao --version
```

## 2. TLS certificate with the IP in the SAN

```
bash
# --- Generate self-signed cert ---
sudo mkdir -p /opt/openbao/tls
sudo openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout /opt/openbao/tls/tls.key \
  -out /opt/openbao/tls/tls.crt \
  -subj "/CN=openbao" \
  -addext "subjectAltName=IP:10.206.213.242,IP:127.0.0.1,DNS:localhost"
```
```
# --- Permissions ---
sudo chown -R openbao:openbao /opt/openbao/tls
sudo chmod 640 /opt/openbao/tls/tls.key
sudo chmod 644 /opt/openbao/tls/tls.crt
```

## 3. Server config

```
bash
# --- /etc/openbao/openbao.hcl ---
sudo tee /etc/openbao/openbao.hcl > /dev/null <<'EOF'
ui            = true
disable_mlock = true

api_addr      = "https://10.206.213.242:8200"
cluster_addr  = "https://10.206.213.242:8201"

storage "raft" {
  path    = "/opt/openbao/data"
  node_id = "openbao-1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_cert_file   = "/opt/openbao/tls/tls.crt"
  tls_key_file    = "/opt/openbao/tls/tls.key"
}
EOF
```
```
# --- Data dir + start ---
sudo mkdir -p /opt/openbao/data
sudo chown -R openbao:openbao /opt/openbao/data
sudo systemctl enable --now openbao
sudo systemctl status openbao --no-pager
```

## 4. Firewall (if ufw is active)

```
bash
sudo ufw allow 8200/tcp
```
## 5. Initialize and unseal

```
bash
# --- Client env ---
export BAO_ADDR=https://10.206.213.242:8200
export BAO_CACERT=/opt/openbao/tls/tls.crt

# --- Init (save this output offline, it is shown only once) ---
bao operator init -key-shares=5 -key-threshold=3 | tee ~/openbao-init.txt
chmod 600 ~/openbao-init.txt

# --- Unseal (run 3 times with 3 different unseal keys) ---
bao operator unseal
bao operator unseal
bao operator unseal
```
```
# --- Login with the root token ---
bao login
bao status
```
```
# Get the Role ID (static, goes into Gitea org secret)
bao read auth/approle/role/gitea-runner/role-id

# Generate a Secret ID (also goes into Gitea org secret)
bao write -f auth/approle/role/gitea-runner/secret-id
```

#### This will generate VAULT_ROLE_ID, VAULT_SECRET_ID that runner need to connect to openbau to get other secrets.

----------------------------------------------------------------------------------------------------------------------

# Next steps are same as GHA secret file - repeated here 


## Step 1

### Enable KV v2 secrets engine:

```
bash
bao secrets enable -path=homelab kv-v2
```
### AppRole Auth for the Gitea Runner
AppRole gives the runner a Role ID + Secret ID pair instead of a long-lived token. The runner exchanges these for a short-lived token at the start of each job.


### Enable AppRole auth

```
bash

bao auth enable approle
```
### Create a policy for the runner

```
openbao policy write gitea-runner - <<'EOF'
path "homelab/data/lxd" {
  capabilities = ["read"]
}
path "homelab/data/seaweed" {
  capabilities = ["read"]
}
path "homelab/data/ansible" {
  capabilities = ["read"]
}
path "homelab/data/microk8s" {
  capabilities = ["read"]
}
EOF
```
### Create the AppRole

```
bao write auth/approle/role/gitea-runner \
  token_policies="gitea-runner" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=0   # 0 = never expires; tighten this in prod
```

---------------------------------------------------------------
## Step 2:
Write all your secrets into organised paths:
First manually create cert files on Openbao server and manually copy paste from laptop

bash
# LXD credentials
bao kv put homelab/lxd  address="10.0.0.250"   client_cert="$(cat /root/certs/lxd/lxd-client.crt)"   client_key="$(cat /root/certs/lxd/lxd-client.key)"


# Seaweed credentials
bao kv put homelab/seaweed   access_key="bafd89b41f6b0db671dd"   secret_key="19d118af5ee3420fb47c1463d3aa34b82b992e28"   endpoint="http://10.206.213.241:8333"   bucket=".tfstate"

# Ansible SSH keys
bao kv put homelab/ansible   ssh_private_key="(cat/root/certs/ansible/idrsa)"  sshpublickey="(cat /root/certs/ansible/id_rsa.pub)"

#Microk8s (.kube/config)
bao kv put homelab/microk8s kubeconfig=@/tmp/kube.yaml

Before that:
On microk8s server
cat ~/.kube/config
Copy the entire output.
On OpenBao VM
Paste it into a file:
vi /tmp/kube.yaml
Store kubeconfig:

Verify:
bash
bao kv get homelab/lxd
bao kv get homelab/minio
bao kv get homelab/ansible


Step 3  — Update Gitea Org Secrets
Replace your 9 secrets with just 2:
Old Secrets (9)
New Secrets (2)
LXD_ADDRESS, LXD_CLIENT_CERT, LXD_CLIENT_KEY, LXD_TRUST_PASSWORD, MINIO_ACCESS_KEY, MINIO_SECRET_KEY, MINIO_ENDPOINT, ANSIBLE_SSH_PRIVATE_KEY, ANSIBLE_SSH_PUBLIC_KEY
VAULT_ROLE_ID, VAULT_SECRET_ID

In Gitea → Infra org → Settings → Secrets:
VAULT_ROLE_ID   = <role-id from above>
VAULT_SECRET_ID = <secret-id from above>
VAULT_ADDR      = http://vault01.lxd:8200   # or make this a 3rd secret
—-----------------------------------------------

