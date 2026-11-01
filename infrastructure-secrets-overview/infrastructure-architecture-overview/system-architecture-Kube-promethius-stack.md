# System Architecture

## System Architecture Kube-promethius-stack

Mental model for a typical **kube-prometheus-stack** installation based on your values, it would look more like this:
```
Namespace: monitoring
│
├── Deployment
│ ├── kube-prometheus-stack-operator
│ │ └── Pod
│ │
│ ├── kube-prometheus-stack-grafana
│ │ └── Pod
│ │
│ └── kube-state-metrics
│ └── Pod
│
├── StatefulSet
│ ├── prometheus-kube-prometheus-stack-prometheus
│ │ └── Pod
│ │
│ └── alertmanager-kube-prometheus-stack-alertmanager
│ └── Pod
│
├── DaemonSet
│ └── prometheus-node-exporter
│ └── Pod (one per node)
│
├── Service
│ ├── kube-prometheus-stack-grafana
│ ├── kube-prometheus-stack-prometheus
│ ├── kube-prometheus-stack-alertmanager
│ ├── kube-prometheus-stack-operator
│ ├── kube-state-metrics
│ └── prometheus-node-exporter
│
├── ServiceMonitor
│ ├── kube-apiserver
│ ├── kubelet
│ ├── coredns
│ ├── kube-state-metrics
│ ├── prometheus-node-exporter
│ ├── prometheus
│ ├── alertmanager
│ └── grafana (optional depending on chart version)
│
├── PodMonitor
│ └── (chart/version dependent)
│
├── PrometheusRule
│ ├── alertmanager.rules
│ ├── kubernetes-apps.rules
│ ├── kubernetes-storage.rules
│ ├── kubernetes-system.rules
│ ├── kube-apiserver.rules
│ ├── kubelet.rules
│ ├── node.rules
│ ├── prometheus.rules
│ └── many more default rule groups
│
├── Prometheus (CRD object)
│ └── kube-prometheus-stack-prometheus
│
├── Alertmanager (CRD object)
│ └── kube-prometheus-stack-alertmanager
│
├── PVC
│ ├── prometheus-db-prometheus-kube-prometheus-stack-prometheus-0
│ ├── alertmanager-db-alertmanager-kube-prometheus-stack-alertmanager-0
│ └── grafana-storage
│
├── ConfigMap
│ ├── grafana-dashboards
│ ├── grafana-datasources
│ ├── alertmanager-config
│ ├── prometheus-rules
│ └── operator-generated configs
│
├── Secret
│ ├── grafana-admin-credentials
│ ├── alertmanager-config
│ ├── prometheus-tls-assets
│ └── operator-generated secrets
│
├── ServiceAccount
│ ├── kube-prometheus-stack-operator
│ ├── prometheus
│ ├── alertmanager
│ ├── grafana
│ ├── kube-state-metrics
│ └── node-exporter
│
├── Role
│ ├── grafana
│ ├── operator
│ └── various component roles
│
├── RoleBinding
│ ├── grafana
│ ├── operator
│ └── various component bindings
│
├── ClusterRole
│ ├── kube-prometheus-stack-operator
│ ├── prometheus
│ ├── kube-state-metrics
│ └── node-exporter
│
├── ClusterRoleBinding
│ ├── kube-prometheus-stack-operator
│ ├── prometheus
│ ├── kube-state-metrics
│ └── node-exporter
│
└── Endpoints / EndpointSlices
├── prometheus
├── alertmanager
├── grafana
├── kube-state-metrics
└── node-exporter
```
The most important thing to remember is:

```
Pods (running code)
│
├── Prometheus Operator
├── Prometheus
├── Alertmanager
├── Grafana
├── kube-state-metrics
└── node-exporter
```
Everything else is mostly:

```
Configuration objects
Security objects
Networking objects
Storage objects
Monitoring objects
```
stored in Kubernetes (etcd/dqlite) and watched by ```controllers/operators``` that run inside those Pods. The ```rometheus Operator Pod``` is what makes many of the monitoring CRDs such as **ServiceMonitor, PrometheusRule, Prometheus, and Alertmanager** actually do something

```
Above line diagram

```
                                [ USER / ADMIN ]
                                        |
                         1. Apply YAML (ServiceMonitors, Rules) <----------------- Via gitea repo
                                        |
                                        v
[--------------------------- KUBERNETES API SERVER ---------------------------]
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

---
## Kube-promethius-grafana stack components

```
Component	        Pod Name (Typical)	                Purpose
Prometheus	        prometheus-kube-prometheus-0	        The database that "scrapes" and stores metrics.
Grafana	                grafana-xxxxxxx-xxxx	                The web UI where you build dashboards.
Alertmanager	        alertmanager-kube-prometheus-0	        Handles the logic for sending emails/Slack pings when things break.
Operator	        prometheus-operator-xxxx-xxxx	        The manager that coordinates the pods above.
Node Exporter	        prometheus-node-exporter-xxxx	        One pod per node in your cluster to monitor hardware.
                                                                label them via ServiceMonitors yaml and operator auto picks.
Go App                  Go app pod                              (:8080/metrics) <--- (Exposed via Go Client Library) (API for Prometheus to pull)
                                                                label them via ServiceMonitors yaml and operator auto picks.
```
---

## Node exporter connects via

```
Method	                What the Exporter uses to "Login"	Where you put the Creds
Node Exporter	        Local System Permissions	        Linux User/Group (root/prometheus)
SNMP	                Community String / SNMPv3 Auth	        Exporter snmp.yml config
HTTP API	        API Key / Basic Auth	                Exporter config file or Env Vars
Metrics Endpoints	Bearer Tokens / TLS Certs	        Exporter config file
Logs	                OS Read Permissions	                chmod / chown on the log files

```
---

## Note
Go app / exporter dont need authentication to prometheus: We label them via ServiceMonitors yaml and operator auto picks.
Go app/exporter only need authentication for the hardware/VM/system they are collecting data from





