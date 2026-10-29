
#                   Architecture Diagram (VM deployment - Go app deployment)
---

VM Deployment
* [Infrastructure Archtecture - GHA - terraform - ansible - LXD - seaweed (S3) - Org level secrets](#infrastructure-archtecture---gha---terraform---ansible---lxd---seaweed-s3---org-level-secrets)
* [Infrastructure Archtecture - GHA - terraform - ansible - LXD - seaweed (S3) - openbao (vault)](#infrastructure-archtecture---gha---terraform---ansible---lxd---seaweed-s3---openbao-vault)
* [Infrastructure Archtecture - GHA - terraform - ansible](#infrastructure-archtecture---gha---terraform---ansible)

Go app deployment
* [Infrastructure Archtecture - GHA - kubernetes - openbao (vault)](#infrastructure-archtecture---gha---kubernetes---openbao-vault)
* [Secrets Architecture - Go app - kubernetes - openbao (vault)](#secrets-architecture---go-app---kubernetes---openbao-vault)
* [Secrets architecture - GHA - kubernetes - openbao (vault)](#secrets-architecture---gha---kubernetes---openbao-vault)

Kubernetes
* [Kubernetes Internal Architecture](#kubernetes-internal-architecture)
* [Kube promethius stack Interal Architecture](#kube-promethius-stack-interal-architecture)

--- 
# VM Deployment

## Infrastructure Archtecture - GHA - terraform - ansible - LXD - seaweed (S3) - Org level secrets

```
 Developer / GitHub Actions Runner
 ----main commands----
 terraform plan / apply
 ansible-playbook
 ---------------------


 Gitea / Developer
 ┌─────────────────────────────────────────┐
 │  Terraform, ansible                     │ ----------------------------(Org level secrets for rubber)
 |  GHA workflows, roles                   │                                    ANSIBLE_SSH_PRIVATE_KEY 
 |                                         |                                    ANSIBLE_SSH_PUBLIC_KEY
 |                                         |                                    LXD_ADDRESS
 |                                         |                                    LXD_CLIENT_CERT
 |                                         |                                    LXD_CLIENT_KEY
 |                                         |                                    S3_ACCESS_KEY
 |                                         |                                    S3_BUCKET
 |                                         |                                    S3_ENDPOINT
 |                                         |                                    S3_SECRET_KEY 
 |                                         |     
 └─────────────────┬───────────────────────┘
                   │
                   |
                   |
                   ▼
 ┌───────────────────────────────────────────┐
 │        Runner / Developer                 │  ----------------------- (Runner picks secrets from Openbao )
 |                                           |                          (Developer picks from env variables)
 |       (Docker-based, LXD VM)              |  
 |                                           |                             
 |                                           |                           
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
 │      Seaweed    │                 |
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
### Infrastructure Archtecture - GHA - terraform - ansible - LXD - seaweed (S3) - openbao (vault)

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
 │      Seaweed    │                 |
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
---
## Infrastructure Archtecture - GHA - terraform - ansible

* GHA workflows
  - Local / reusable
* Terraform modules
  - local / reusable
* ansible
  - local roles / reusasble galaxy

Two scearios
```
One:
1. Local GHA workflows (.gitea/workflows)
2. Local terraform modules (terraform/modules/*.tf)
3. Local ansible roles (ansible/roles)
4. Local terraform no modules (terraform/*.tf)

Two
1. Reusable workflows (http://gitea.local/admin/reusable-workflows)
2. Reusable terraform modules (http://gitea.local/admin/reusable-modules)
3. Reusable ansiible roles (http://gitea.local/admin/reusable-galaxy-roles-curl)
```
---
# Go app deployment

## Infrastructure Archtecture - GHA - kubernetes - openbao (vault)

```
Developer / GitHub Actions Runner
----main commands----
docker build
docker push
helm install/upgrade
---------------------

Gitea / Developer
+-----------------------------------+
| Source Code + Helm Chart Folder   |
| Chart.yaml, values.yaml, templates|
+-----------------------------------+
        │
        |
+------------------+
|Runner / Developer├──────────────────────────────────────────────────────► docker build
+------------------+                                                      │
        │                                                                 ▼
        │                                                        +------------------+
        │                                                        | Docker Image     |
        │                                                        | (tagged version) |
        │                                                        +------------------+
        │                                                                 │
        │                                                                 ▼
        │                                                             docker push
        │                                                                 │
        │                                                                 ▼
        │                                                       +------------------+
        │                                                       | MicroK8s Registry|
        │                                                       | Stores container |
        │                                                       | images           |
        │                                                       +------------------+
        │
        └───────────────► helm install/upgrade
                              │
                              ▼
                      +----------------------+
                      | Helm Metadata        |
                      | - Release name       |
                      | - Values used        |
                      | - Chart version      |
                      | - History snapshot   |
                      +----------------------+
                              │
                              ▼
                      +----------------------+
                      | Kubernetes Objects   |
                      | - Deployment         |
                      | - Service            |
                      | - Ingress            |
                      | - ConfigMaps/Secrets |
                      +----------------------+
                              │
                              ▼
                      +----------------------+
                      | Pods (runtime)       |
                      | - Pull images from   |
                      |   MicroK8s registry  |
                      | - Ephemeral, auto-   |
                      |   recreated by K8s   |
                      +----------------------+

```
## Secrets Architecture - Go app - kubernetes - openbao (vault)

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

## Secrets architecture - GHA - kubernetes - openbao (vault)

Correct. The three Gitea org secrets are for the runner’s bootstrap credentials only:
```
Gitea org secrets (VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID)
        │  AppRole login
        ▼
OpenBao  →  homelab/data/microk8s   (kubeconfig)
         →  homelab/data/registry   (registry address)  ← new (maybe later. still hardcoded in GHA workflow 10.206.213.243:3200)
```

```
┌──────────────────────────────────────────────────┐
│              Gitea Org Secrets                   │
│  ├── VAULT_ADDR                                  │
│  ├── VAULT_ROLE_ID      → same for ALL workflows │
│  └── VAULT_SECRET_ID                             │
└──────────────────────────┬───────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────┐
│                   OpenBao                        │
│               AppRole login                      │
└──────────────────────────┬───────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────┐
│         homelab/data/microk8s                    │
│              kubeconfig                          │
│   (server: https://10.206.213.243:16443)         │
└──────────────────────────┬───────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────┐
│           GHA Runner (LXD VM)                    │
│     export KUBECONFIG=/tmp/kubeconfig            │
└──────────┬───────────────┬───────────────┬───────┘
           │               │               │
           ▼               ▼               ▼
    ┌────────────┐  ┌────────────┐  ┌────────────┐
    │helm deploy │  │helm deploy │  │helm deploy │
    │   dev      │  │  staging   │  │   live     │
    └────────────┘  └────────────┘  └────────────┘

PR Pipeline:   build-pr → deploy-dev-pr → deploy-staging-pr
Push Pipeline: build    → deploy-live
```
---

## Kubernetes Internal Architecture

The namespace is the outer container, and everything else lives inside it.
```
Cluster (MicroK8s)
└── Namespace: dev                          ← you provide (--namespace dev)
    ├── Deployment: go-lxd-vm-dashboard     ← you provide (chart: {{ .Release.Name }})
    │   └── ReplicaSet: go-lxd-vm-dashboard-7d9f8b6c5   ← auto (Deployment name + hash)
    │       └── Pod: go-lxd-vm-dashboard-7d9f8b6c5-x2k4p ← auto (ReplicaSet name + random)
    ├── Service: go-lxd-vm-dashboard        ← you provide (chart: {{ .Release.Name }})
    └── Ingress: go-lxd-vm-dashboard-ingress ← you provide (chart: {{ .Release.Name }}-ingress)
```
---

## Kube promethius stack Interal Architecture

```
                                [ USER / ADMIN ]
                                        |
                         1. Apply YAML (ServiceMonitors, Rules) <----------------- Via gitea repo
                                        |
                                        v
[--------------------------- KUBERNETES API SERVER ---------------------------------]
                                        |
                                        | (Watches for changes)
                                        v
                            [ PROMETHEUS OPERATOR POD ]
                            "The Manager / Foreman"
                                        |
           -------------------------------------------------------------
           | (Configures)               | (Configures)                 | (Configures)
           v                            v                              v
   [ PROMETHEUS POD ] <---------- [ ALERTMANAGER ]                [ GRAFANA POD ]
   "The Database"      (Alerts)    "The Notifier"                 "The Visualizer"
           |                                                           |
           | 2. PULL / SCRAPE                                          | 3. QUERY
           | (Every 15-30s)                                            | (On Demand)
           |                                                           |
           |                                                           v
           |                                                     (User Web Browser)
           |                                                     "lxd-dashboard.local"
|          | 
           |
           |
           |                           
           |---> [ NODE EXPORTER ] ----> (Hardware/OS Metrics)
           |
           |---> [ YOUR GO APP ] 
                    |
                    |-- (:8080/metrics) <--- (Exposed via Go Client Library) (API for Prometheus to pull)
                    |
                    |-- [ INTERNAL APP LOGIC ]
                            |
                            |-- (LXD SDK) ----> [ LXD SERVER ]
                            |-- (Vault SDK) ---> [ OPENBAO ]
```