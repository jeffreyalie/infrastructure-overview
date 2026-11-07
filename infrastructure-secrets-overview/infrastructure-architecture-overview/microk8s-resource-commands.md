# MicroK8s: Listing Kubernetes Resources by Namespace and Helm Release

This guide contains useful commands for inspecting Kubernetes resources
and Helm releases in a MicroK8s cluster.

## 1. List all namespaces

``` bash
microk8s kubectl get namespaces
```

Short form:

``` bash
microk8s kubectl get ns
```

## 2. List resources in a namespace

For example, list common resources in the `monitoring` namespace:

``` bash
microk8s kubectl get all -n monitoring
```

List common resources across all namespaces:

``` bash
microk8s kubectl get all -A
```

> **Note:** `kubectl get all` does not literally show every Kubernetes
> resource type. For example, ConfigMaps, Secrets, PVCs, and
> ServiceMonitors are not included by this command.

## 3. List resources associated with a Helm release

Helm commonly labels resources with:

``` text
app.kubernetes.io/instance=<release-name>
```

For example, list common resources associated with the
`kube-prometheus-stack` release in the `monitoring` namespace:

``` bash
microk8s kubectl get all -n monitoring \
  -l app.kubernetes.io/instance=kube-prometheus-stack
```

You can also request specific resource types, including
monitoring-related custom resources:

``` bash
microk8s kubectl get \
  deployments,services,pods,configmaps,secrets,pvc,servicemonitors,prometheuses,alertmanagers \
  -n monitoring \
  -l app.kubernetes.io/instance=kube-prometheus-stack
```

The label selector only returns resources that carry the specified
label. Not every resource created or managed by a chart is guaranteed to
have that label.

## 4. List Helm releases and their namespaces

``` bash
microk8s helm3 list -A
```

This displays Helm releases across namespaces, including their release
names and namespaces.

Example:

  Helm release              Namespace
  ------------------------- --------------
  `kube-prometheus-stack`   `monitoring`
  `grafan-lxd-monitoring`   `default`
  `gitea`                   `default`

The names above are examples; the actual releases in your cluster may
differ.

## 5. Useful commands for a MicroK8s lab

  ----------------------------------------------------------------------------------------------------------------------------------
  What you want                       Command
  ----------------------------------- ----------------------------------------------------------------------------------------------
  List all namespaces                 `microk8s kubectl get ns`

  List common resources in            `microk8s kubectl get all -n monitoring`
  `monitoring`                        

  List common resources in all        `microk8s kubectl get all -A`
  namespaces                          

  List Helm releases across           `microk8s helm3 list -A`
  namespaces                          

  List common resources by Helm       `microk8s kubectl get all -n monitoring -l app.kubernetes.io/instance=kube-prometheus-stack`
  release                             

  List all ServiceMonitors            `microk8s kubectl get servicemonitors -A`

  List all ScrapeConfigs              `microk8s kubectl get scrapeconfigs -A`

  List all ConfigMaps                 `microk8s kubectl get configmaps -A`

  List all PVCs                       `microk8s kubectl get pvc -A`
  ----------------------------------------------------------------------------------------------------------------------------------

## 6. Key distinction: namespace vs. Helm release

-   **Namespace:** Identifies where a Kubernetes resource exists.
-   **Helm release:** Identifies a Helm installation that manages a
    collection of Kubernetes resources.

They are different concepts. A Helm release is installed into a
namespace, but a namespace can contain resources from multiple Helm
releases as well as resources that were created without Helm.

## Recommended commands to remember

``` bash
# Show Helm releases and their namespaces
microk8s helm3 list -A

# Show common resources in the monitoring namespace
microk8s kubectl get all -n monitoring

# Show common resources across all namespaces
microk8s kubectl get all -A
```
