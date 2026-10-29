# Infrastructure Secrets Archtecture

## Infrastructure Secrets Archtecture VM Deployment - GHA - terraform - ansible - LXD - seaweed (S3) - openbao (vault)
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

## Pre steps - Add variables and secrets to vault:
Go to Bao server terminal:

### Initialize and unseal

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

### Get the Role ID (static, goes into Gitea org secret)
```
bao read auth/approle/role/gitea-runner/role-id
```

### Generate a Secret ID (also goes into Gitea org secret)
```
bao write -f auth/approle/role/gitea-runner/secret-id
```

This will generate VAULT_ROLE_ID, VAULT_SECRET_ID that runner need to connect to openbau to get other secrets.

## Step 1 - Setup Approl

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

## Step 2:

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

## Step 3  — Update Gitea Org Secrets

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