# Prometheus Exporter Scenarios

How Prometheus collects metrics from different kinds of targets: `node_exporter`, `snmp_exporter`, `mysqld_exporter`, `postgres_exporter`, LXD and the Go app.

---

## Table of Contents

- [0. Overview: what Prometheus does](#0-overview-what-prometheus-does)
- [1. node_exporter: agent on the server](#1-node_exporter-agent-on-the-server)
- [2. snmp_exporter: proxy pod for devices](#2-snmp_exporter-proxy-pod-for-devices)
- [3. mysqld_exporter / postgres_exporter](#3-mysqld_exporter--postgres_exporter)
- [4. Already in this homelab: LXD and the Go app](#4-already-in-this-homelab-lxd-and-the-go-app)
- [5. Side-by-side summary](#5-side-by-side-summary)
- [6. The metricsPath rule](#6-the-metricspath-rule)

---

## 0. Overview: what Prometheus does

```
┌────────────────────────────────────────────────────────────────┐
│ MicroK8s cluster (namespace: monitoring)                       │
│                                                                │
│   Prometheus Operator ──reads──► ServiceMonitor / ScrapeConfig │
│          │                                                     │
│          ▼ builds scrape jobs                                  │
│   Prometheus ──pulls (HTTP GET, every 30s)──► targets          │
│          │                                                     │
│          ▼ query                                               │
│   Grafana (dashboards)      Alertmanager (alerts)              │
└────────────────────────────────────────────────────────────────┘

Rule: Prometheus only PULLS over HTTP, and only reads Prometheus text format.
      Something on the other end must speak that format: built in, agent, or proxy.
```

Three patterns for "something on the other end":

| Pattern | Where it runs | Examples |
|---|---|---|
| Agent on the target | Installed on the monitored machine | `node_exporter` |
| Proxy next to Prometheus | Pod in the cluster, queries the target remotely | `snmp_exporter`, `blackbox_exporter`, DB exporters (optional) |
| Built into the app | Inside the application | LXD (`/1.0/metrics`), Go app (`/metrics`) |

---

## 1. node_exporter: agent on the server

node_exporter

No pod is needed for an Ubuntu server. node_exporter is a small program you install on the server and run as a systemd service.
It’s that program, not Ubuntu itself, that publishes the data at http://<server-ip>:9100/metrics. Note the port, 9100, and /metrics with an s.
Prometheus scrapes it directly, with no middleman.

SNMP

The device only answers SNMP queries on UDP 161, in SNMP’s own format (values identified by OIDs, described by MIB files). It publishes no HTTP endpoint.
The snmp_exporter pod queries the device, translates the OIDs into named Prometheus metrics (ifHCInOctets, and so on), and serves them over HTTP.
The URL belongs to the exporter pod, not the device: http://snmp-exporter...:9116/snmp?target=<device-ip>&module=.... Prometheus never contacts the device directly.
node_exporter:  Prometheus ──HTTP──► Ubuntu server :9100/metrics

SNMP:           Prometheus ──HTTP──► snmp_exporter pod :9116/snmp?target=<device>
                                         │ SNMP over UDP 161
                                         ▼
                                       device

The only node_exporter pods you’ll see in your cluster are the DaemonSet from kube-prometheus-stack. They monitor the MicroK8s node itself, not your other Ubuntu servers.

```
┌─────────────────────┐                  ┌──────────────────────────────┐
│ Prometheus          │  HTTP GET        │ Ubuntu server 10.0.0.60      │
│ (monitoring ns)     │ ───────────────► │                              │
│                     │  :9100/metrics   │  node_exporter (systemd)     │
│                     │ ◄─────────────── │   reads /proc and /sys       │
│                     │  node_* metrics  │   serves :9100/metrics       │
└─────────────────────┘                  └──────────────────────────────┘
        ▲
        │ reads
┌─────────────────────────────────────────────┐
│ ScrapeConfig                                │
│   staticConfigs:                            │
│     - targets: ["10.0.0.60:9100"]           │
│   (no metricsPath, /metrics is the default) │
└─────────────────────────────────────────────┘

Installed on: the monitored server (cannot run remotely from a pod)
Credentials:  none
Open port:    TCP 9100 from the MicroK8s node to the server
Example:      node_filesystem_avail_bytes, node_cpu_seconds_total
```

Special case: kube-prometheus-stack runs `node_exporter` as a DaemonSet pod. That one monitors only the MicroK8s node, not other servers.

Minimal ScrapeConfig:

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: ScrapeConfig
metadata:
  name: lxd-host-node
  namespace: monitoring
spec:
  staticConfigs:
    - targets: ["10.0.0.60:9100"]
      labels:
        lxd_host: lxd01
```

---

## 2. snmp_exporter: proxy pod for devices

```
┌──────────────┐ HTTP GET                    ┌──────────────────────────┐
│ Prometheus   │ /snmp?target=10.0.0.1       │ snmp-exporter POD        │
│              │ &module=if_mib              │ (monitoring ns)          │
│              │ &auth=cisco_v3              │  :9116                   │
│              │ ──────────────────────────► │                          │
│              │                             │  1. receives request     │
│              │                             │  2. asks device via SNMP │
│              │                             │  3. maps OIDs to names   │
│              │ ◄────────────────────────── │  4. returns Prom text    │
│              │   ifHCInOctets, ...         └────────────┬─────────────┘
└──────────────┘                                          │ SNMP v3
        ▲                                                 │ UDP 161
        │ reads                                           ▼
┌──────────────────────────────────────────┐   ┌──────────────────────────┐
│ ScrapeConfig                             │   │ Cisco / Palo Alto        │
│   metricsPath: /snmp         (REQUIRED)  │   │ 10.0.0.1, 10.0.0.2       │
│   params: module=[if_mib], auth=[...]    │   │ SNMP agent enabled       │
│   targets: ["10.0.0.1","10.0.0.2"]       │   │ (no HTTP metrics URL)    │
│   relabelings:                           │   └──────────────────────────┘
│     device IP  -> __param_target         │
│     device IP  -> instance label         │
│     __address__ -> snmp-exporter...:9116 │
└──────────────────────────────────────────┘

Runs as:      pod in the cluster (one pod serves many devices)
Credentials:  SNMPv3 user and passwords in the exporter's config (or a Secret)
Open port:    UDP 161 from the exporter pod / node to each device
Trap:         without metricsPath: /snmp the target shows UP but no device data
```

SNMP is not HTTP. The device only answers SNMP queries on UDP 161. Only the exporter pod speaks HTTP to Prometheus.

ScrapeConfig:

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: ScrapeConfig
metadata:
  name: network-devices
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  metricsPath: /snmp
  params:
    module: [if_mib]
    auth: [cisco_v3]
  staticConfigs:
    - targets: ["10.0.0.1", "10.0.0.2"]    # the devices, not the exporter
  scrapeInterval: 60s
  relabelings:
    - sourceLabels: [__address__]
      targetLabel: __param_target
    - sourceLabels: [__param_target]
      targetLabel: instance
    - targetLabel: __address__
      replacement: snmp-exporter-prometheus-snmp-exporter.monitoring.svc:9116
```

Use the real service name from `microk8s kubectl get svc -n monitoring | grep snmp`.

---

## 3. mysqld_exporter / postgres_exporter

The databases don't publish Prometheus metrics. The exporter logs in as a SQL client, runs stats queries, and serves the results. It can run as a pod or on the database server, and Prometheus can't tell the difference.

### Option A: proxy pod in Kubernetes

```
┌──────────────┐  HTTP GET    ┌────────────────────────────┐   MySQL protocol   ┌──────────────┐
│ Prometheus   │ ───────────► │ mysqld-exporter POD        │ ─────────────────► │ MySQL        │
│              │  Service     │  :9104/metrics             │   TCP 3306         │ 10.0.0.50    │
│              │ ◄─────────── │  login from K8s Secret     │ ◄───────────────── │              │
└──────────────┘  mysql_up    └────────────────────────────┘   SHOW STATUS      └──────────────┘
       ▲
       │ reads
┌──────────────────────────────┐
│ ServiceMonitor               │      Same shape for Postgres:
│   selector: app=<exporter>   │      Prometheus ► postgres-exporter POD :9187
│   endpoints: port: metrics   │                 ► Postgres TCP 5432 (pg_stat_*)
└──────────────────────────────┘

Needs: a Service in front of the pod, a Secret with the DB login
Open port: DB port (3306 / 5432) from the cluster to the database
```

### Option B: exporter installed on the database server

```
┌──────────────┐  HTTP GET          ┌────────────────────────────────────────┐
│ Prometheus   │ ─────────────────► │ DB server 10.0.0.50                    │
│              │  :9104/metrics     │                                        │
│              │  (or :9187)        │  exporter (systemd) ◄─localhost─► DB   │
│              │ ◄───────────────── │   login stored on this server          │
└──────────────┘  mysql_up / pg_up  └────────────────────────────────────────┘
       ▲
       │ reads
┌───────────────────────────────────────┐
│ ScrapeConfig                          │
│   targets: ["10.0.0.50:9104"]         │
└───────────────────────────────────────┘

Open port: exporter port (9104 / 9187) from Prometheus to the DB server
```

### Choosing

| | On the database server | Pod in Kubernetes |
|---|---|---|
| URL Prometheus scrapes | `http://<db-host>:9104/metrics` (MySQL) or `:9187/metrics` (Postgres) | `http://<exporter-svc>:9104/metrics`, found through a Service |
| Scrape object | `ScrapeConfig` with a static IP target | `ServiceMonitor` |
| Exporter connects to the DB over | `localhost` | The network |
| Port to open | The exporter port, from Prometheus | The DB port, from the cluster |
| Credentials | Stored on the DB server | Kubernetes Secret |

Use a dedicated low-privilege database user:

- **MySQL:** `PROCESS`, `REPLICATION CLIENT` and `SELECT` on the stats schemas.
- **Postgres:** the built-in `pg_monitor` role.

One exporter normally serves one database. `snmp_exporter` differs: one pod serves many devices through the `target` parameter.

Typical metrics: `mysql_up`, `mysql_global_status_threads_connected`, `pg_up`, `pg_stat_database_numbackends`. The `*_up` metric is `1` only when the exporter could log in, so it is the first thing to alert on.

---

## 4. Already in this homelab: LXD and the Go app

```
LXD (built in):
  Prometheus ──HTTPS + client cert──► LXD 10.0.0.250:8443/1.0/metrics
  ScrapeConfig: metricsPath: /1.0/metrics, tlsConfig: lxd-metrics-tls Secret

Go app (built in):
  Prometheus ◄── ServiceMonitor ◄── Service ◄── Pod :8080/metrics
  The pod's own code (client_golang) serves the metrics
```

`ServiceMonitor` works only for things running in Kubernetes behind a Service. LXD is an external machine, so it uses a `ScrapeConfig` with a fixed address instead.

---

## 5. Side-by-side summary

```
┌───────────────────┬───────────────┬────────────┬─────────────┬──────────────────────┐
│ Source            │ Pattern       │ Port       │ metricsPath │ Scrape object        │
├───────────────────┼───────────────┼────────────┼─────────────┼──────────────────────┤
│ node_exporter     │ agent on host │ 9100       │ default     │ ScrapeConfig         │
│ snmp_exporter     │ proxy pod     │ 9116       │ /snmp       │ ScrapeConfig+relabel │
│ mysqld_exporter   │ pod OR on DB  │ 9104       │ default     │ ServiceMonitor (pod) │
│                   │               │            │             │ ScrapeConfig (on DB) │
│ postgres_exporter │ pod OR on DB  │ 9187       │ default     │ ServiceMonitor (pod) │
│                   │               │            │             │ ScrapeConfig (on DB) │
│ LXD               │ built in      │ 8443       │ /1.0/metrics│ ScrapeConfig + TLS   │
│ Go app            │ built in      │ 8080       │ default     │ ServiceMonitor       │
└───────────────────┴───────────────┴────────────┴─────────────┴──────────────────────┘

Credentials always go to the exporter, never to Prometheus:
  SNMP user ► snmp_exporter config      DB login ► exporter Secret or local config
  LXD cert  ► Secret read by Prometheus (mTLS is needed to reach the endpoint itself)
```

---

## 6. The metricsPath rule

- Prometheus only knows one default scrape path: `/metrics`.
- Each target decides which paths it serves. Prometheus doesn't know which program is behind a URL; it sends a GET and parses the response.
- Set `metricsPath` only when the target's data is **not** on `/metrics`.

| Path | Defined by | Prometheus default? | Set `metricsPath`? |
|---|---|---|---|
| `/metrics` | Prometheus convention (node_exporter, DB exporters, Go app) | Yes | No |
| `/snmp` | `snmp_exporter` | No | Yes, `/snmp` |
| `/1.0/metrics` | LXD (API version prefix) | No | Yes, `/1.0/metrics` |

`snmp_exporter` also serves `/metrics`, but that only shows the exporter's own health. Forgetting `metricsPath: /snmp` leaves the target UP with no device data.
