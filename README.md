
* Infradtructure Architecture
  - Infrastructure Archtecture VM Deployment - Gitea - Gitea runner - terraform - ansible - LXD - seaweed (S3)
  - Infrastructure Archtecture VM Deployment - Gitea - Gitea runner - terraform - ansible - LXD - seaweed (S3) - openbao (vault)
  - Infrastructure Archtecture VM Deployment - GHA workflows - terraform modules - ansible roles / galaxy
  - Infrastructure Archtecture Go app deployment - Gitea - Gitea runner - kubernetes - openbao (vault)
  - Infrastructure Architecture Kube-promethius-stack Goap and other devices Deployment

* Infrastrucure Secrets Architecture
  - Infrastructure Secrets Archtecture Go app deployment - Microk8s - openbao (vault)
  - Infrastructure Secrets Archtecture Go app deployment - GHA runner - Microk8s - openbao (vault)

* Systems Architecture
  - System Architecture Kubernetes
  - System Architecture Kube-promethius-stack
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
* [System Architecture - Kubernetes](#system-architecture---kubernetes)
* [System Architecture - Kube promethius stack](#system-architecture---kube-promethius-stack)

--- 
## Infrastructure Archtecture VM Deployment - GHA - terraform - ansible - LXD - seaweed (S3) - Org level secrets
## Infrastructure Archtecture VM Deployment - GHA - terraform - ansible - LXD - seaweed (S3) - openbao (vault)
## Infrastructure Archtecture VM Deployment - GHA workfloes - terraform modules - ansible roles / galaxy
## Infrastructure Archtecture Go app deployment - GHA - kubernetes - openbao (vault)
## Infrastructure Architecture Kube-promethius-stack Goap and other devices

## Infrastructure Secrets Archtecture VM Deployment - GHA - terraform - ansible - LXD - seaweed (S3) - openbao (vault)
## Infrastructure Secrets Archtecture VM Deployment - GHA - terraform - ansible - LXD - seaweed (S3) - Org level secrets
## Infrastructure Secrets Archtecture Go app deployment - GHA runner - Microk8s - openbao (vault)
## Infrastructure Secrets Archtecture Go app deployment - Microk8s - terraform - GHA runner - openbao (vault)

## System Architecture Kube-promethius-stack
## System Architecture Kubernetes

--- 

## Infrastructure Archtecture VM Deployment - GHA - terraform - ansible - LXD - seaweed (S3) - Org level secrets

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
## Infrastructure Archtecture VM Deployment - GHA - terraform - ansible - LXD - seaweed (S3) - openbao (vault)

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
## Infrastructure Archtecture VM Deployment - GHA workfloes - terraform modules - ansible roles / galaxy

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
## Infrastructure Archtecture Go app deployment - GHA - kubernetes - openbao (vault)
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
---
## Infrastructure Architecture Kube-promethius-stack Goap and other devices

Terminology

In Prometheus, the target (your “server” side) exposes metrics over HTTP, and Prometheus (your “client” side) pulls them on a schedule, here every 30s. Nothing is pushed.

So yes, you configure both ends, but what each end needs depends on the type of target.

Three kinds of targets
1. Go app (you control the code)
Side	What you configure
Target	Add prometheus/client_golang and expose /metrics on :8080
Prometheus	A ServiceMonitor that finds your Service
yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: go-lxd-vm-dashboard
  namespace: dev
spec:
  selector:
    matchLabels:
      app: go-lxd-vm-dashboard   # must match the Service's labels
  endpoints:
    - port: http                 # must match the Service's port *name*
      path: /metrics
      interval: 30s

Your service.yaml already has the app: label and name: http, so it will match. Your serviceMonitorSelector: {} means Prometheus picks it up from any namespace.

One gotcha in your Go code: / is your only handler, and it calls Vault and LXD on every request. Register /metrics separately with promhttp.Handler(), or Prometheus will trigger a Vault login every 30s.

2. Cisco / Palo Alto (can’t install anything on them)

You can’t run an exporter on the device, so you run one next to Prometheus that talks to the device on its behalf:

Prometheus ──scrape──► snmp-exporter (pod) ──SNMP──► Cisco / Palo Alto
Side	What you configure
Device	Enable SNMP (prefer v3 with a dedicated read-only user), and allow the exporter’s IP through ACLs or firewall rules
Exporter	Deploy snmp_exporter with the device credentials in its auth config, plus a module for the metrics you want (interfaces, CPU, and so on)
Prometheus	A ScrapeConfig (or Probe) listing the device IPs and routing them through the exporter
yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: ScrapeConfig
metadata:
  name: network-devices
  namespace: monitoring
spec:
  staticConfigs:
    - targets: ["10.0.0.1", "10.0.0.2"]   # the devices
  metricsPath: /snmp
  params:
    module: [if_mib]
    auth: [cisco_v3]
  relabelings:
    - sourceLabels: [__address__]
      targetLabel: __param_target
    - sourceLabels: [__param_target]
      targetLabel: instance
    - targetLabel: __address__
      replacement: snmp-exporter.monitoring.svc:9116   # scrape the exporter, not the device

Palo Alto also supports SNMP, and there are dedicated exporters that use its XML/REST API for richer data such as sessions and threat counters. Cisco gear with streaming telemetry (gNMI) can use a gNMI exporter instead.

3. Servers, VMs, and other things with a native endpoint
Linux VMs: run node_exporter, then add a ScrapeConfig with static targets, since they are outside the cluster.
LXD itself: it exposes /1.0/metrics natively. You add a metrics-type client certificate (lxc config trust add --type=metrics) and scrape it with TLS settings. That could replace some of your Go app’s queries for CPU and memory.
Reachability checks: blackbox_exporter handles ping, HTTP, and TCP probes.
Summary: do you need config on both ends?
Target type	Target side	Exporter in the middle	Prometheus side
Go app	Instrument code, expose /metrics	None	ServiceMonitor
Cisco / Palo Alto	Enable SNMP or API, allow access	snmp_exporter (or vendor exporter)	ScrapeConfig / Probe
Linux VM	Install node_exporter	None	ScrapeConfig
LXD	Trust a metrics cert	None	ScrapeConfig with TLS

The Prometheus side is the same each time: tell it what to scrape. The target side varies from instrumenting code to configuring a device.

Where credentials go

This matches your README note, with one refinement. Targets don’t authenticate to Prometheus, since Prometheus does the pulling. But:

Exporters need credentials to the device (SNMP community or v3 user, API keys). Put these in a Kubernetes Secret mounted into the exporter. You could source them from OpenBao.
Prometheus needs credentials to the target only if the metrics endpoint itself is protected (basic auth, bearer token, or mTLS, as with LXD’s endpoint).
Network paths

The Prometheus and exporter pods must be able to reach the devices (routing and firewall) on UDP 161 for SNMP, or on the API port. This is the most common reason a target shows “down”.

Which device do you want to start with? I can write the full exporter deployment and secret handling for it, or the client_golang changes for your main.go.

---

## Infrastructure Secrets Archtecture Go app deployment - Microk8s - terraform - GHA runner - openbao (vault)

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

## Infrastructure Secrets Archtecture Go app deployment - GHA runner - Microk8s - openbao (vault)

Correct. The three Gitea org secrets are for the runner’s bootstrap credentials only:
```
Gitea org secrets (VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID)
        │  AppRole login
        ▼
OpenBao  →  homelab/data/microk8s   (kubeconfig)
         →  homelab/data/registry   (registry address)  ← new (maybe later. still hardcoded in GHA workflow 10.206.213.243:3200)
```
-------
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







#########################################################
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

## System Architecture - Kubernetes

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

## System Architecture - Kube promethius stack

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