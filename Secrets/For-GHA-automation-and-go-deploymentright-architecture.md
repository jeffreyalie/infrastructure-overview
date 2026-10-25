# The Right Architecture — Go + MicroK8s + OpenBao + LXD and GHA runner  - gitea org level secrets

> Secrets architecture for a Go app running in MicroK8s that connects to LXD using credentials fetched from OpenBao at runtime.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Full Picture](#full-picture)
- [Step 1 — Store OpenBao Credentials in K8s Secrets](#step-1--store-openbao-credentials-in-k8s-secrets)
- [Step 2 — Inject into Pod via Helm values.yaml](#step-2--inject-into-pod-via-helm-valuesyaml)
- [Step 3 — Go App Authenticates to OpenBao and Fetches LXD Secrets](#step-3--go-app-authenticates-to-openbao-and-fetches-lxd-secrets)
- [Step 4 — Store LXD Secrets in OpenBao](#step-4--store-lxd-secrets-in-openbao)
- [Build and Deploy to MicroK8s](#build-and-deploy-to-microk8s-manual)

---

## Architecture Overview

```
K8s Secret (openbao-creds)         ← created manually via kubectl  
├── VAULT\_ADDR                         in each namespace (dev/staging/live)  
├── VAULT\_ROLE\_ID  
└── VAULT\_SECRET\_ID  
         │  
         │
      Helm Charts  injected via envFrom in values.yaml ---injected---> deployment.yaml  
         │  
         ▼  
      Go App (main.go)  
      getSecrets() function  
         │  
         │  AppRole login on every HTTP request  
         ▼  
      OpenBao  
         │  
         └── homelab/data/lxd  
                  │  
                  ├── client\_cert    → LXD TLS auth  
                  └── client\_key     → LXD TLS auth  
                           │  
                           ▼  
                        LXD API  
                  https://10.0.0.162:8443  
                           │  
                           ▼  
                    Instance list  
                    (name, type, status, IPs)  
                           │  
                           ▼  
                      index.html  
                      rendered to browser

```

## Full Picture

```
Git / Helm chart
└── No secrets ever (Only reads from Kubernetes Secrets (microk8s)) ✅

Kubernetes Secrets (microk8s)
└── VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID  (bootstrap only)

OpenBao
└── LXD_CLIENT_CERT, LXD_CLIENT_KEY  (actual sensitive secrets)

Go Pod
├── Reads VAULT_ vars from K8s env
├── Authenticates to OpenBao
└── Gets LXD certs at runtime → connects to LXD
```

This matches exactly how your Gitea Actions pipeline works — org-level vars for bootstrap, OpenBao for the real secrets.


## Where Gitea org secrets fit in

### The runner (GHA)

Correct. The three Gitea org secrets are for the runner’s bootstrap credentials only:
```
Gitea org secrets (VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID)
        │  AppRole login
        ▼
OpenBao  →  homelab/data/microk8s   (kubeconfig)
         →  homelab/data/registry   (registry address)  ← new
```

---

## Step 1 — Store OpenBao Credentials in K8s Secrets

```bash
microk8s kubectl create namespace dev

microk8s kubectl create secret generic openbao-creds \
  --from-literal=VAULT_ADDR=https://10.248.42.125:8200 \
  --from-literal=VAULT_ROLE_ID=99f070cb-f0cc-cd3d-bc55-2ac2a23b90bc \
  --from-literal=VAULT_SECRET_ID=4e17b858-475e-cfa8-d03a-bbd2337c8450 \
  --namespace=dev
```

---

## Step 2 — Inject into Pod via Helm values.yaml

```yaml
# values.yaml
secret:
  name: openbao-creds
```

```yaml
# templates/deployment.yaml
spec:
  containers:
    - name: lxd-reader
      image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
      envFrom:
        - secretRef:
            name: {{ .Values.secret.name }}   # injects all three VAULT_ vars
```

---

## Step 3 — Go App Authenticates to OpenBao and Fetches LXD Secrets

```go
package main

import (
    "fmt"
    "os"
    vault "github.com/hashicorp/vault/api"
)

func getSecrets() (cert, key string, err error) {
    // reads from pod environment (injected by K8s Secret)
    vaultAddr := os.Getenv("VAULT_ADDR")
    roleID    := os.Getenv("VAULT_ROLE_ID")
    secretID  := os.Getenv("VAULT_SECRET_ID")

    // connect to OpenBao
    config := vault.DefaultConfig()
    config.Address = vaultAddr
    client, err := vault.NewClient(config)
    if err != nil {
        return "", "", err
    }

    // authenticate with AppRole
    data := map[string]interface{}{
        "role_id":   roleID,
        "secret_id": secretID,
    }
    resp, err := client.Logical().Write("auth/approle/login", data)
    if err != nil {
        return "", "", err
    }
    client.SetToken(resp.Auth.ClientToken)

    // fetch LXD secrets from OpenBao
    secret, err := client.Logical().Read("secret/data/lxd")
    if err != nil {
        return "", "", err
    }

    cert = secret.Data["data"].(map[string]interface{})["LXD_CLIENT_CERT"].(string)
    key  = secret.Data["data"].(map[string]interface{})["LXD_CLIENT_KEY"].(string)

    return cert, key, nil
}
```

Go module setup:

```bash
go mod init go-lxd-vm-dashboard
go get github.com/hashicorp/vault/api
go get github.com/canonical/lxd/client
go get github.com/canonical/lxd/shared/api
```

---

## Step 4 — Store LXD Secrets in OpenBao

```bash
# Run on OpenBao server
bao kv put secret/lxd \
  LXD_CLIENT_CERT=@/path/to/client.crt \
  LXD_CLIENT_KEY=@/path/to/client.key
```

---

## Build and Deploy to MicroK8s (manual)

```bash
# Build the Docker image
docker build -t go-lxd-vm-dashboard:latest .

# Load the image into MicroK8s
docker save go-lxd-vm-dashboard:latest > go-lxd-vm-dashboard.tar
microk8s ctr image import go-lxd-vm-dashboard.tar

# Create namespace and secrets
microk8s kubectl create namespace dev

microk8s kubectl create secret generic openbao-creds \
  --from-literal=VAULT_ADDR=https://10.248.42.125:8200 \
  --from-literal=VAULT_ROLE_ID=99f070cb-f0cc-cd3d-bc55-2ac2a23b90bc \
  --from-literal=VAULT_SECRET_ID=4e17b858-475e-cfa8-d03a-bbd2337c8450 \
  --namespace=dev

# Deploy via Helm
microk8s helm upgrade --install go-lxd-vm-dashboard ./helm-chart --namespace dev

# Force restart to refresh environment variables
microk8s kubectl rollout restart deployment go-lxd-vm-dashboard -n dev
```

If want to recreate delete first:
```
microk8s kubectl delete secret openbao-creds \-n dev  
microk8s kubectl delete secret openbao-creds \-n staging  
microk8s kubectl delete secret openbao-creds \-n live

Restart microk8s pods:  
microk8s kubectl rollout restart deployment/go-lxd-vm-dashboard \-n dev  
microk8s kubectl rollout restart deployment/go-lxd-vm-dashboard \-n staging  
```
