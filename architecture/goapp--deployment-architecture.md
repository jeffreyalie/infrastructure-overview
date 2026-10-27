# Go app deployment architecture - Microk8s - terraform - GHA runner - openbao (vault)

---
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

#### My Key ppints:

1. **Docker build:** compiles the golang. Don't need seperate go compile. Docekr builder has built-in go compiler 
2. **Docekr push:** Pushes built to registry (either harbor or buit-in microk8s) 
3. **Helm Charts:** Docker compose and helm charts are more or less the same
4. **Helm intall/upgrade:** uploads or update the helm values and to microk8s internal databas and kublets pull the respective built from registry and makes a pod.

---

### 🔍 Key Clarifications
* **Docker Build** → Creates the container image.
* **ocker Push →** Uploads image into MicroK8s’ internal registry.
* **Registry →** Permanent storage for images.
* **Helm Install/Upgrade →** Sends rendered manifests to MicroK8s.
* **Helm Metadata →** Stored in cluster secrets/configmaps, keeps values/history.
* **Kubernetes Objects →** Persisted in etcd, define deployments/services/ingress.
* **Pods →** Ephemeral runtime containers, recreated automatically from Deployment spec.
### ⚡ Takeaway
* **Local chart folder →** only used at install/upgrade time.
* **Registry →** permanent image storage.
* **Cluster (etcd + Helm metadata) →** permanent spec + release state.
* **Pods →** runtime only, not the source of truth

---

#### 📂 Helm Chart Folder Structure

```
Your local folder:
helm-chart/
├── Chart.yaml
├── templates/
│   ├── deployment.yaml
│   ├── ingress.yaml.txt
│   └── service.yaml
├── values.yaml
└── README.md
``` 
### 🔍 What Happens on microk8s helm install/upgrade
* **Local Chart Packaging**
    - When you run microk8s helm install ./helm-chart (or upgrade), Helm packages this folder into a chart archive (.tgz) and sends the manifests to the Kubernetes API server inside MicroK8s.
* **What Gets Uploaded**
    - The YAML manifests (deployment.yaml, service.yaml, ingress.yaml) are rendered using values.yaml.
    - Helm then applies those manifests to the MicroK8s cluster.
    - The chart folder itself (your local files) is not permanently uploaded into MicroK8s. It’s only used at install/upgrade time to generate Kubernetes resources.
* **What MicroK8s Keeps**
    - The resulting Kubernetes objects (Deployments, Services, Ingresses, ConfigMaps, etc.) created from your templates.
    - Helm metadata stored in the cluster (in a Secret or ConfigMap in the kube-system namespace) to track release history.
    - It does not keep your raw chart folder structure — only the rendered manifests and Helm release state.

### 🐳 Role of Registry

* Your Docker build/push workflow pushes container images into the MicroK8s internal registry.
* The Helm chart references those images (via values.yaml → image.repository + image.tag).
* MicroK8s pulls the image from its registry when creating pods.



### Summary
* Helm chart folder → stays local, only manifests are sent during install/upgrade.
* MicroK8s keeps → Kubernetes objects + Helm release metadata.
* Registry keeps → container images built/pushed via Docker.

So the flow is: **Docker build → push to registry → Helm install/upgrade (using chart manifests) → MicroK8s runs pods with images from registry.**

-----

##                                          Kubernetes - Microk8s structure diagram - old

---

```
                                            Developer / GitHub Actions Runner
                                            +-----------------------------------+
                                            | Source Code + Helm Chart Folder   |
                                            | Chart.yaml, values.yaml, templates|
                                            | README.md                         |
                                            +-----------------------------------+
                                                 |                     |                                                                                      
                                                 |                     |                    
                                                 |                     | 
                                                 |                     |                                  
                                        helm install/upgrade       Docker build push -------------------+                                       
                                                 │                                                      |                      
                                                 |                                              +-----------------------+
                                                 |                                              |Local registry / Harbor|
                                                 |                                              +-----------------------+
                                                 ▼                                                      |         
                            +------------------------------------------------------------+              |
                            |  Kubernetes Controllers (inside MicroK8s) creates pod       |             |   
                            | - Deployment Controller ensures desired pods               |              |
                            |  - Service Controller manages networking                   |              |  
                            |  - Ingress Controller manages routing                      |              |  
                            |  - Reconciliation loop keeps actual state = desired state  |              |   
                            |- Kubelet on the node is the one that pulls the image       |              |
                            |  (first time or when missing) and starts                   |              |
                            +------------------------------------------------------------+              |
                                                        |                                               |                         
                                                        |                                               |  
                                            +----------------------+                                    |   
                                            | Helm Metadata        |                                    |
                                            | (Secrets/ConfigMaps) |                                    |
                                            | - Release name       |                                    |   
                                            | - Chart version      |                                    | 
                                            | - Values used        |                                    |
                                            | - History snapshot   |                                    |
                                            +----------------------+                                    |
                                                        │                                               |
                                                        ▼                                               |
                                            +----------------------+                                    |
                                            | Kubernetes Objects   |                                    |
                                            | (stored in etcd)     |                                    |    
                                            | - Deployment (spec   |                                    |    
                                            |   references registry|                                    |    
                                            |   image)             |                                    |    
                                            | - Service            |                                    |        
                                            | - Ingress            |                                    |           
                                            | - ConfigMaps/Secrets |                                    |                
                                            +----------------------+                                    |                    
                                                        │                                               |                
                                                        ▼                                               |            
                                            +--------------------------+                                |
                                            | Pods (runtime)           |                                |    
                                            |--------------------------|                                |
                                            |- Kubelet Pull images from|                                |
                                            |   MicroK8s registry      |   <----Kubelet on each node----+
                                            | - Ephemeral, auto-       |        pulls images and starts 
                                            |   recreated by K8s       |        containers
                                            +--------------------------+

```
---

## 🧩 What Happens Step by Step

## 1. Helm Client Action

* Helm reads your chart (Chart.yaml, values.yaml, templates/*.yaml).
* It renders the manifests into plain Kubernetes YAML.
* It sends those manifests to the Kubernetes API server inside MicroK8s.

## 2. Kubernetes API Server

* Accepts the manifests and stores them in **etcd** (the cluster database).
* At this point, Helm’s job is done — Kubernetes now owns the lifecycle.

## 3. Kubernetes Controllers

* **Deployment Controller:** Ensures the desired number of pods are running, recreates them if deleted.
* **ReplicaSet Controller:** Tracks pod replicas.
* **Service Controller:** Manages networking endpoints.
* **Ingress Controller:** Manages external routing.

👉 These controllers continuously reconcile the “desired state” (from your manifests) with the “actual state” of the cluster.

## 4. Pods

* Created by the Deployment spec.
* Each pod pulls its container image from the MicroK8s registry (if not cached locally).
* Pods are ephemeral — if they die, the Deployment controller recreates them automatically.

---

## 🔗 Where Registry Fits

### Kubelet (on each node)
The kubelet is the agent running on every node.
* When the scheduler assigns a pod to a node, the kubelet is responsible for creating the container runtime process.
* The kubelet checks if the image is already cached locally.
    * If cached → reuse.
    * If not cached → kubelet instructs the container runtime (containerd in MicroK8s) to pull the image from the registry.