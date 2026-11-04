# Infrastructure Secrets Archtecture

## Infrastructure Secrets Archtecture VM Deployment - Gitea - Gitea runner - terraform - ansible - LXD - seaweed (S3) - openbao (vault) [Vault level secreats]
```
 Developer / GitHub Actions Runner
 ----main commands----
 terraform plan / apply
 ansible-playbook
 ---------------------


 Gitea / Developer
 ┌─────────────────────────────────────────┐
 │  Terraform, ansible                     │ ----------------------------(Org level secrets for openbao only)
 |  GHA workflows, roles                   │                      (VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID)
 └─────────────────┬───────────────────────┘
                   │
                   |
                   |
                   ▼
 ┌───────────────────────────────────────────┐
 │        Runner / Developer                 │  ----------------------- (Runner picks secrets from Openbao )
 |                                           |                                  homelab/data/lxd
 |       (Docker-based, LXD VM)              |                                  homelab/data/seaweed	
 |                                           |                                  homelab/data/ansible
 |                                           |                             
 |                                           |                            (Developer picks from env variables)
 |                                           |
 └───────┬───────────────────────────┬───────┘
         │                           │
         |                           |
         |                           |
Terraform│ plan / apply              │Ansible-playbook
         |                           |
         |                           |       
         ▼                           |
 ┌─────────────────┐                 |               
 │     Seaweed     │                 |
 │    backend s3   │                 |
 │    (TF state)   │                 |
 └─────────────────┘                 |
         │                           |      
         │                           |
         │                           |
 ┌─────────────────┐                 |               
 │   LXD / KVM     │                 |
 │  (localhost:    │                 |       
 │    8443)        │                 |      
 └─────────────────┘                 |
         |                           |
         |                           |
         |                           |
 ┌─────────────────┐                 |       
 │  Target VM      │                 |      
 │  Ubuntu 26.04   │ +---------------+                   
 │With ansible user|
 └─────────────────┘

```
```
Gitea Org Secrets
├── VAULT_ADDR
├── VAULT_ROLE_ID        → same for ALL workflows
└── VAULT_SECRET_ID      → same for ALL workflows
         │
         ▼
      OpenBao
      (AppRole login)
         │
         ├── homelab/data/lxd        → LXD TLS cert/key    → go app talks to LXD
         ├── homelab/data/Seaweed    → Seaweed creds          → Terraform state backend
         ├── homelab/data/ansible    → Ansible secrets      → Ansible playbooks
         └── homelab/data/microk8s   → kubeconfig          → helm deploy to MicroK8s

```
---
Teble of content:

- [Where secrets are used](#where-secrets-are-used)
- [Total secrets used](#total-secrets-used)

* [How to get secrets](#how-to-get-secrets)
* [How to deploy in Openbao (Vault)](#how-to-deploy-in-openbao-vault)

---
## Where Secrets Are Used

**For GHA automation** (`.gitea/workflows/*.yml`):
- Add at org or repo level as Gitea secrets
- Define actual values in OpenBao

**For manual use:**
- Export all as environment variables in your shell

---
### Total secrets used
```
+------------------------------------------------+----------------------------------------+
|               Old Secrets (9)                  |               New Secrets (2)          |
+------------------------------------------------+----------------------------------------+
| LXD_ADDRESS, LXD_CLIENT_CERT, LXD_CLIENT_KEY,  |      VAULT_ROLE_ID, VAULT_SECRET_ID    |
| LXD_TRUST_PASSWORD,                            |                                        |
| S3_SECRET_KEY, S3_ENDPOINT,                    |                                        |
| ANSIBLE_SSH_PRIVATE_KEY, ANSIBLE_SSH_PUBLIC_KEY|                                        |
+------------------------------------------------+----------------------------------------+
```
## How to get Secrets

**1. How to get VAULT_ROLE_ID, VAULT_SECRET_ID**
role-id is like user to read gitea-runner approll/policies and secrets. Command only reads the existing role-id for gitea-runner policy
secret-is is password generated via command
```
# Get the Role ID (static, goes into Gitea org secret)
bao read auth/approle/role/gitea-runner/role-id

# Generate a Secret ID (also goes into Gitea org secret)
bao write -f auth/approle/role/gitea-runner/secret-id
```
**2. How to Get LXD_CLIENT_CERT and LXD_CLIENT_KEY**

Step 1 — Generate a Client Certificate

Run this on your LXD host:
```bash
# Create a directory for the cert
mkdir -p ~/lxd-certs && cd ~/lxd-certs

# Generate client cert + key (valid 10 years)
openssl req -x509 -newkey ec \
  -pkeyopt ec_paramgen_curve:secp384r1 \
  -sha384 -keyout gitea-runner.key \
  -out gitea-runner.crt \
  -days 3650 -nodes \
  -subj "/CN=gitea-runner"
```
Step 2 — Trust the Certificate in LXD

```bash
# Add the cert as a trusted client
lxc config trust add ~/lxd-certs/gitea-runner.crt --name gitea-runner
```

Or via **LXD Web UI**: Settings → Trusted clients → Add certificate → paste `gitea-runner.crt` content.

Verify it's trusted:

```bash
lxc config trust list
```

Step 3 — Add Secrets to Gitea

| Secret Name | Value | How to Get |
|-------------|-------|-----------|
| `LXD_CLIENT_CERT` | Content of `gitea-runner.crt` | `cat ~/lxd-certs/gitea-runner.crt` |
| `LXD_CLIENT_KEY` | Content of `gitea-runner.key` | `cat ~/lxd-certs/gitea-runner.key` |
| `LXD_ADDRESS` | Your host IP | `hostname -I \| awk '{print $1}'` |
| `ANSIBLE_SSH_PUBLIC_KEY` | Your ansible pub key | See section below |

---

**3. How to Get ANSIBLE_SSH_PUBLIC_KEY**

Step 1 — Generate Your SSH Key Pair

```bash
ssh-keygen -t ed25519 -C "ansible" -f ~/.ssh/ansible_id_ed25519
# Press Enter twice for no passphrase (recommended for automation)
```

This creates two files:

- `~/.ssh/ansible_id_ed25519` — **private key** (keep safe, never share)
- `~/.ssh/ansible_id_ed25519.pub` — **public key** (this goes into Gitea)

Step 2 — Copy the Public and private Keys Content

```bash
cat ~/.ssh/ansible_id_ed25519.pub
# Output looks like:
# ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... ansible

cat ~/.ssh/ansible_id_ed25519
# Output looks like:
# -----BEGIN OPENSSH PRIVATE KEY-----
# b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
# QyNTUxOQAAACDl5gGhp+SGauJBBrFceeeRNwsO2fvt/HknBabL2DWK6QAAAJA/ww5MP8MO
# TAAAAAtzc2gtZWQyNTUxOQAAACDl5gGhp+SGauJBBrFceeeRNwsO2fvt/HknBabL2DWK6Q
# AAAEBVgtiDH22m4ZJt7cGehwffxqSJjnwAXnM0fhnyBrLHqOXmAaGn5IZq4kEGsVx555E3
# Cw7Z++38eScFpsvYNYrpAAAAB2Fuc2libGUBAgMEBQY=
# -----END OPENSSH PRIVATE KEY-----

```
---

**4. How to get Seaweed keys**

After / during installation of Seaweed we get four credentials variables:
```
sudo grep TF_ /root/seaweedfs-keys.env
sudo cat /etc/seaweedfs/admin.env
```

For webui access only (not used in GHA)
```
  WEED_ADMIN_USER=admin
  WEED_ADMIN_PASSWORD=c5703879fcb973b727484ada
```
Used in GHA

```
  TF_ACCESS=bafd89b41f6b0db671dd
  TF_SECRET=19d118af5ee3420fb47c1463d3aa34b82b992e28

  Used in repo secret as:
  S3_ACCESS_KEY = TF_ACCESS
  S3_SECRET_KEY = TF_SECRET
```
---
## How to deploy in Openbao (Vault)

Go to Bao server terminal:

### Dtep 1 - Initialize and unseal

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

# --- Login with the root token ---
bao login
bao status
```
```
### Get the Role ID (static, goes into Gitea org secret)
```
bao read auth/approle/role/gitea-runner/role-id
```

### Generate a Secret ID (also goes into Gitea org secret)
```
bao write -f auth/approle/role/gitea-runner/secret-id
```
This will generate VAULT_ROLE_ID, VAULT_SECRET_ID that runner need to connect to openbau to get other secrets.
```
## Step 2 - Setup Approl

### Enable KV v2 secrets engine:

```
bash
bao secrets enable -path=homelab kv-v2
Phase 5 — AppRole Auth for the Gitea Runner
AppRole gives the runner a Role ID + Secret ID pair instead of a long-lived token. The runner exchanges these for a short-lived token at the start of each job.
```

```
bash
# Enable AppRole auth
bao auth enable approle
```
### Create a policy for the runner

```

openbao policy write gitea-runner - <<'EOF'
path "homelab/data/lxd" {
  capabilities = ["read"]
}
path "homelab/data/Seaweed" {
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

## Step 3:

Write all your secrets into organised paths:
First manually create cert files on Openbao server and manually copy paste from laptop

```
bash
# LXD credentials
bao kv put homelab/lxd  address="10.0.0.250"   client_cert="$(cat /root/certs/lxd/lxd-client.crt)"   client_key="$(cat /root/certs/lxd/lxd-client.key)"
```
```
# Seaweed credentials
bao kv put homelab/seaweed   access_key="bafd89b41f6b0db671dd"   secret_key="19d118af5ee3420fb47c1463d3aa34b82b992e28"   endpoint="http://10.206.213.241:8333"   bucket=".tfstate"
```
```
# Ansible SSH keys
bao kv put homelab/ansible \
  ssh_private_key="$(cat ~/.ssh/id_rsa)" \
  ssh_public_key="$(cat ~/.ssh/id_rsa.pub)"
```

```
#Microk8s (.kube/config)
openbao kv put homelab/microk8s kubeconfig=@/tmp/kube.yaml

Before that:
On microk8s server
cat ~/.kube/config
Copy the entire output.
On OpenBao VM
Paste it into a file:
vi /tmp/kube.yaml
Store kubeconfig:
```

### Verify:
```
bash
bao kv get homelab/lxd
bao kv get homelab/Seaweed
bao kv get homelab/ansible
```

## Step 4  — Update Gitea Org Secrets

### Replace your 9 secrets with just 2:

```
+------------------------------------------------+----------------------------------------+
|               Old Secrets (9)                  |               New Secrets (2)          |
+------------------------------------------------+----------------------------------------+
| LXD_ADDRESS, LXD_CLIENT_CERT, LXD_CLIENT_KEY,  |      VAULT_ROLE_ID, VAULT_SECRET_ID    |
| LXD_TRUST_PASSWORD,                            |                                        |
| S3_SECRET_KEY, S3_ENDPOINT,                    |                                        |
| ANSIBLE_SSH_PRIVATE_KEY, ANSIBLE_SSH_PUBLIC_KEY|                                        |
+------------------------------------------------+----------------------------------------+
```
### In Gitea → Infra org → Settings → Secrets:
```
VAULT_ROLE_ID   = <role-id from above>
VAULT_SECRET_ID = <secret-id from above>
VAULT_ADDR      = http://vault01.lxd:8200   # or make this a 3rd secret
```