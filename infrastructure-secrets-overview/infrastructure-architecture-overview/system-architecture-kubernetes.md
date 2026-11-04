# System Architecture

## System Architecture Kubernetes

### The namespace is the outer container, and everything else lives inside it.
Each item in your list is a **Kubernetes API resource (object)**. In a Helm chart, you define these resources with a ```kind: ``` field, and Kubernetes stores and manages them via its API server.
```
Helm Chart
    ↓ renders
YAML Manifests
    ↓ submitted to
Kubernetes API Server
    ↓ creates/stores
Objects
    ├── Deployment
    ├── Service
    ├── Ingress
    ├── ServiceMonitor
    ├── ConfigMap
    └── ...
             ↓
Controllers reconcile state
             ↓
ReplicaSets, Pods, Endpoints, etc.
```
1. Kubernetes objects vreated via ```helm upgraade -- install```:

```
Kubernetes API Server - etcd - Cluster (MicroK8s)
│
└── Namespace: dev                          ← You provide (--namespace dev)
    │
    ├── Helm Release: go-lxd-vm-dashboard   ← You provide (after --install)
    │   │
    │   │   Helm manages the following resources:
    │   │
    │   ├── Deployment: go-lxd-vm-dashboard
    │   │       ← You define (chart: {{ .Release.Name }})
    │   │   │
    │   │   └── ReplicaSet: go-lxd-vm-dashboard-7d9f8b6c5
    │   │       ← Kubernetes automatically creates (Deployment + hash)
    │   │       │
    │   │       └── Pod: go-lxd-vm-dashboard-7d9f8b6c5-x2k4p
    │   │           ← Kubernetes automatically creates (ReplicaSet + suffix)
    │   │           │
    │   │           ├── Container(s)        ← Defined in Pod template
    │   │           ├── Volumes             ← Defined in Pod specification
    │   │           ├── Pod IP              ← Assigned by Kubernetes networking
    │   │           └── Metadata            ← Labels, annotations, etc.
    │   │
    │   ├── Service: go-lxd-vm-dashboard
    │   │       ← You define (chart: {{ .Release.Name }})
    │   │
    │   ├── Ingress: go-lxd-vm-dashboard-ingress
    │   │       ← You define (chart: {{ .Release.Name }}-ingress)
    │   │
    │   ├── ServiceMonitor: go-lxd-vm-dashboard
    │   │       ← You define (Helm template / Prometheus Operator CRD)
    │   │
    │   ├── ConfigMap(s)
    │   │       ← You define (Helm template)
    │   │
    │   ├── Secret(s)
    │   │       ← You define or Kubernetes/Helm creates
    │   │
    │   ├── ServiceAccount
    │   │       ← You define (Helm template)
    │   │
    │   ├── HorizontalPodAutoscaler
    │   │       ← You define (Helm template)
    │   │
    │   ├── PersistentVolumeClaim
    │   │       ← You define (Helm template)
    │   │
    │   └── NetworkPolicy
    │           ← You define (Helm template)
    │
    └── Helm Release Secret(s)
            ← Helm automatically creates
            │
            └── sh.helm.release.v1.go-lxd-vm-dashboard.v1
                ← Stores release revision, chart, values and manifests
```
2. ConfigMap created directly through kubectl
```
kubectl create configmap lxd-resources-dashboard \
  --from-file=dashboard.json \
  -n monitoring
```
Logical hierarchy:
```
Kubernetes Cluster (MicroK8s)
│
└── Namespace: monitoring
    │
    ├── ConfigMap: lxd-resources-dashboard
    │       ← Directly managed by kubectl
    │
    ├── Deployment: lxd-monitoring
    │
    ├── Service: lxd-monitoring
    │
    └── Other Kubernetes resources
```
### Each object kind has its own kubectl get command, and you search by name or by label. The two commands you pasted are identical (both get svc), so here is the full set.

#### Search by object kind
```bash
microk8s kubectl get deploy  -n dev      # Deployments
microk8s kubectl get rs      -n dev      # ReplicaSets
microk8s kubectl get pods    -n dev      # Pods
microk8s kubectl get svc     -n dev      # Services
microk8s kubectl get ingress -n dev      # Ingresses
```
Short names: deploy, rs, po, svc, ing. You can combine several kinds in one command:
```bash
microk8s kubectl get deploy,rs,pods,svc,ingress -n dev
```

#### Search by name

Add the object’s name to get just that one:
```bash
microk8s kubectl get deploy go-lxd-vm-dashboard -n dev
microk8s kubectl get svc go-lxd-vm-dashboard -n dev
microk8s kubectl get ingress go-lxd-vm-dashboard-ingress -n dev
microk8s kubectl get pod go-lxd-vm-dashboard-7d9f8b6c5-x2k4p -n dev   # pod names change, so this is rarely useful
```
For more detail on one object, use describe instead of get:

```bash
microk8s kubectl describe svc go-lxd-vm-dashboard -n dev
```
#### Search by label

-l filters any kind by label, and --show-labels just displays the labels in an extra column:

```bash
microk8s kubectl get pods -n dev -l app=go-lxd-vm-dashboard
microk8s kubectl get svc  -n dev -l app=go-lxd-vm-dashboard
microk8s kubectl get all  -n dev -l app=go-lxd-vm-dashboard
```
--show-labels doesn’t filter; it only shows what labels exist so you know what to put after -l:

```bash
microk8s kubectl get svc -n dev --show-labels
microk8s kubectl get pods -n dev --show-labels
```
#### Which objects appear with -l app=...
A label search only finds objects that have that label. In your current chart:
```
+---------------------------------------------------------------------------------------+
| Object	        | Has app: label?	     | Why                                      |
+-------------------+------------------------+------------------------------------------+
| Pod	            | Yes	                 | pod template labels                      |
+-------------------+------------------------+------------------------------------------+
| ReplicaSet	    | Yes	                 | inherits the pod template labels         |
+-------------------+------------------------+------------------------------------------+
| Service	        | Yes	                 | metadata.labels in service.yaml          |
+-------------------+------------------------+------------------------------------------+
| Deployment	    | No	                 | deployment.yaml has no metadata.labels   |
+-------------------+------------------------+------------------------------------------+
| Ingress	        | No	                 | ingress.yaml has no labels               |
+-------------------+------------------------+------------------------------------------+
```
So get all -l app=go-lxd-vm-dashboard will not list the Deployment or the Ingress. (all also excludes Ingresses anyway.)<br>
To make them searchable by label, add labels: under each one’s metadata. Until then, find them by name or by kind.

**Quick summary**
```
+--------------------------------+-----------------------------------+
| You want to find	             |  Use                              |
+--------------------------------+-----------------------------------+
| Everything of one kind	     | get <kind> -n dev                 |
+--------------------------------+-----------------------------------+
| One specific object	         | get <kind> <name> -n dev          |
+--------------------------------+-----------------------------------+
| Everything tagged with a label | get <kinds> -n dev -l key=value   |
+--------------------------------+-----------------------------------+
| See what labels exist	         | get <kind> -n dev --show-labels   |
+--------------------------------+-----------------------------------+
| Across all namespaces	         | replace -n dev with -A            |
+--------------------------------+-----------------------------------+
```
