# Infrastructure Architecture

## Infrastructure Architecture Kube-promethius-stack Goap and other devices Deployment

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