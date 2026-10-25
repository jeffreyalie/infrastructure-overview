# Install MicroK8s on Ubuntu

---

## Table of Contents

- [Step 1 — Install MicroK8s](#step-1--install-microk8s)
- [Step 2 — Enable Essential Add-ons](#step-2--enable-essential-add-ons)
- [Step 3 — Export Kubeconfig](#step-3--export-kubeconfig)
- [Step 4 — Install Lens](#step-4--install-lens)
- [Step 5 — Connect Lens to MicroK8s](#step-5--connect-lens-to-microk8s)
- [Common Issues and Fixes](#common-issues-and-fixes)
- [Fix Missing ~/.kube Directory](#fix-missing-kube-directory)
- [Kubernetes Dashboard](#kubernetes-dashboard)
- [Multiple Users and RBAC](#option-a---multiple-users-and-rbac)

---

## Step 1 — Install MicroK8s

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install MicroK8s via Snap (latest stable channel)
sudo snap install microk8s --classic

# Add your user to the microk8s group
sudo usermod -a -G microk8s $USER

# Create ~/.kube if it doesn't exist, then fix ownership
mkdir -p ~/.kube
sudo chown -f -R $USER ~/.kube

# Apply the new group membership in the current shell (or log out/in)
newgrp microk8s

# Wait until it's ready
microk8s status --wait-ready
```

---

## Step 2 — Enable Essential Add-ons
Add each add-on one by one. Not all in same.

```bash
microk8s enable dns hostpath-storage registry ingress helm3 dashboard
```

| Add-on | Purpose |
|--------|---------|
| `dns` | CoreDNS for service discovery |
| `storage` | Default storage class |
| `dashboard` | Kubernetes dashboard |

You can also enable `ingress`, `metrics-server`, or `registry` depending on your needs.

---

## Step 3 — Export Kubeconfig

Lens requires kubeconfig to connect:

```bash
microk8s config > ~/.kube/config
```

> If you already have other clusters, merge configs carefully instead of overwriting.

---

## Step 4 — Install Lens

Download Lens from [https://k8slens.dev](https://k8slens.dev) and install it on Ubuntu:

```bash
sudo snap install kontena-lens --classic
# or use .deb package from their site

lens
```

---

## Step 5 — Connect Lens to MicroK8s

1. Open Lens → **Clusters** → **Add Cluster**
2. Select **Browse kubeconfig** and point to `~/.kube/config`
3. Lens will detect the MicroK8s cluster and add it
4. Click the cluster to connect — you'll see nodes, pods, services, and workloads

---

## Common Issues and Fixes

| Issue | Fix |
|-------|-----|
| Permissions error | Ensure your user is in the `microk8s` group and kubeconfig file is owned by you |
| Cluster not showing in Lens | Verify kubeconfig path and run `microk8s config` again |
| Networking issues | Enable `dns` and `ingress` add-ons |

---

## Fix Missing ~/.kube Directory

MicroK8s doesn't create `~/.kube` by default. Fix it manually:

```bash
# Step 1 — Create the directory
mkdir -p ~/.kube

# Step 2 — Export kubeconfig
microk8s config > ~/.kube/config

# Step 3 — Fix permissions
sudo chown -R $USER:$USER ~/.kube

# Step 4 — Verify
kubectl get nodes --kubeconfig ~/.kube/config
```

---
## Fix - Docker request https

On the host running the Gitea runner:
``` 
bash
sudo mkdir -p /etc/docker
sudo vi /etc/docker/daemon.json
json
{
  "insecure-registries": ["10.206.213.243:32000"]
}
```
If the file already has other settings, add the key alongside them rather than replacing the file. Then restart Docker:
```
bash
sudo systemctl restart docker
```
---
## Kubernetes Dashboard - deprecated -

After enabling the dashboard add-on:

```bash
# Port-forward the dashboard service
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443

# Check service name if needed
kubectl -n kubernetes-dashboard get svc

# Get login token (if RBAC is not enabled)
microk8s kubectl describe secret -n kube-system microk8s-dashboard-token
```

Open [https://localhost:8443](https://localhost:8443) in your browser and paste the token.

---

## Option A - Multiple Users and RBAC

 Authentication Methods Comparison

| Method | For | Expires | Revokable | Auditable | Setup |
|--------|-----|---------|-----------|-----------|-------|
| ServiceAccount token | Machines / CI-CD | Yes (short JWT) | Delete SA | ❌ No | Easy |
| Client Certificate | Humans | No (you set days) | Revoke cert | ✅ Yes (CN=name) | Medium |
| OIDC | Humans | Yes (auto-refreshes) | Revoke in provider | ✅ Yes (email) | Complex |

### Creating a Namespace and ServiceAccount

```bash
microk8s kubectl create namespace dev
microk8s kubectl -n dev create serviceaccount qa-user
```

#### Binding to a ClusterRole (cluster-wide)

```bash
microk8s kubectl create clusterrolebinding qa-user-binding \
  --clusterrole=view \
  --serviceaccount=dev:qa-user
```

#### Binding to a Namespace only

```bash
microk8s kubectl create rolebinding qa-user-binding \
  --clusterrole=view \
  --serviceaccount=dev:qa-user \
  --namespace=dev
```

#### Generating a Token for the ServiceAccount

```bash
microk8s kubectl -n dev create token qa-user
```

#### Example User Kubeconfig

```yaml
apiVersion: v1
kind: Config
clusters:
- name: microk8s-cluster
  cluster:
    server: https://127.0.0.1:16443
    certificate-authority-data: <CA_CERT_DATA>
users:
- name: qa-user
  user:
    token: <TOKEN_FROM_ABOVE>
contexts:
- name: qa-user-context
  context:
    cluster: microk8s-cluster
    user: qa-user
    namespace: dev
current-context: qa-user-context
```

------------------------------

### Option B — Client Certificates (recommended for homelab)

#### How it works

```
Admin generates certificate for Jeffrey
    ↓
Certificate signed by cluster's CA
    ↓
Jeffrey puts it in ~/.kube/config
    ↓
Kubernetes trusts it because it's signed by cluster CA
```

#### Step 1: Generate Jeffrey’s private key
```
bash
openssl genrsa -out jeffrey.key 2048
```

#### Step 2: Create Certificate Signing Request (CSR)
```
bash
openssl req -new \
  -key jeffrey.key \
  -out jeffrey.csr \
  -subj "/CN=jeffrey/O=dev-team"
# CN = username Kubernetes will see
# O  = group (optional, used for group-based RBAC)
```

#### Step 3: Sign it with the cluster CA (admin does this)
```
bash
# get cluster CA from microk8s
sudo cat /var/snap/microk8s/current/certs/ca.crt
sudo cat /var/snap/microk8s/current/certs/ca.key

# sign jeffrey's certificate
openssl x509 -req \
  -in jeffrey.csr \
  -CA /var/snap/microk8s/current/certs/ca.crt \
  -CAkey /var/snap/microk8s/current/certs/ca.key \
  -CAcreateserial \
  -out jeffrey.crt \
  -days 365
```

#### Step 4: Create RBAC for jeffrey (admin does this)
```
bash
# jeffrey is now a real User, no ServiceAccount needed
microk8s kubectl create clusterrolebinding jeffrey-binding \
  --clusterrole=view \
  --user=jeffrey        # matches CN= in the certificate
```

#### Step 5: Jeffrey’s kubeconfig file
```
yaml
apiVersion: v1
kind: Config
clusters:
- name: microk8s-cluster
  cluster:
    server: https://<CLUSTER_IP>:16443
    certificate-authority-data: <CA_CERT_BASE64>
users:
- name: jeffrey
  user:
    client-certificate-data: <jeffrey.crt in base64>  # not a token
    client-key-data: <jeffrey.key in base64>           # private key
contexts:
- name: jeffrey-context
  context:
    cluster: microk8s-cluster
    user: jeffrey
    namespace: dev
current-context: jeffrey-context
Convert certs to base64 for kubeconfig
bash
cat jeffrey.crt | base64 -w 0    # paste into client-certificate-data
cat jeffrey.key | base64 -w 0    # paste into client-key-data
```
----------------------------------

### Option C — OIDC (proper enterprise way)

#### How it works
```
Human logs in → Google / Keycloak / GitHub
    ↓
Gets OIDC token (JWT) from identity provider
    ↓
Passes token to Kubernetes API
    ↓
Kubernetes verifies token with identity provider
    ↓
RBAC checks permissions
```

#### Step 1: Configure microk8s API server to trust OIDC provider
```
bash
# edit API server config
sudo nano /var/snap/microk8s/current/args/kube-apiserver

# add these lines
--oidc-issuer-url=https://accounts.google.com
--oidc-client-id=my-kubectl-client
--oidc-username-claim=email
--oidc-groups-claim=groups

# restart
sudo systemctl restart snap.microk8s.daemon-kubelite
```

#### Step 2: Jeffrey logs in via OIDC (using kubelogin plugin)
```
bash
# install kubelogin
kubectl krew install oidc-login

# jeffrey runs this once — opens browser login
kubectl oidc-login setup \
  --oidc-issuer-url=https://accounts.google.com \
  --oidc-client-id=my-kubectl-client
```

#### Step 3: Jeffrey’s kubeconfig
```
yaml
apiVersion: v1
kind: Config
clusters:
- name: microk8s-cluster
  cluster:
    server: https://<CLUSTER_IP>:16443
    certificate-authority-data: <CA_CERT_BASE64>
users:
- name: jeffrey
  user:
    exec:                                      # runs kubelogin to get token
      apiVersion: client.authentication.k8s.io/v1beta1
      command: kubectl
      args:
      - oidc-login
      - get-token
      - --oidc-issuer-url=https://accounts.google.com
      - --oidc-client-id=my-kubectl-client
contexts:
- name: jeffrey-context
  context:
    cluster: microk8s-cluster
    user: jeffrey
    namespace: dev
current-context: jeffrey-context
```

-----------------------------------------

> **Note:** `oidc-login setup` only tests + prints a snippet. You still build the kubeconfig manually.
             For CI/CD create kube/config file and create a secret in vault
----------------------------------------

### Key principle — Authentication vs Authorization

```
Step 1 → Authentication   "Who are you?"
         Certificate / OIDC / Token proves identity

Step 2 → Authorization    "What can you do?"
         RBAC always required — regardless of auth method
```
--------------------------------------
