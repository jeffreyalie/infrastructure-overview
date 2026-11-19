# MicroK8s / Kubernetes: Managing Application Files with Helm

This guide explains three ways to make application files such as `index.html` available to containers running in MicroK8s:

1. **Dockerfile `COPY` + Helm** — package files into a container image and deploy that image.
2. **ConfigMap + Helm** — store non-sensitive configuration/static files in Kubernetes and mount them into a Pod.
3. **`kubectl cp`** — manually copy files between Ubuntu and a running Pod's container.

The examples use Nginx, a MicroK8s cluster, and a local MicroK8s registry.

---

## 1. How Docker and Kubernetes concepts relate

| Docker / Compose | Kubernetes / MicroK8s |
|---|---|
| Docker image | Container image |
| Docker container | Container running inside a Pod |
| Docker Compose | Kubernetes manifests, often managed with Helm |
| Dockerfile `COPY` | Same Dockerfile instruction; Kubernetes runs the resulting image |
| Bind mount | HostPath volume (not usually portable) or ConfigMap/Secret volume, depending on purpose |
| Docker named volume | PersistentVolume / PersistentVolumeClaim |
| `docker cp` | `kubectl cp` |
| `docker compose up -d` | `kubectl apply` or `helm upgrade --install` |

Kubernetes does not use Helm to copy files directly into containers. Helm creates or updates Kubernetes resources. Kubernetes then uses those resources to configure and run Pods.

---

## 2. Method A: Dockerfile `COPY` + Helm

**Best suited to:** reproducible CI/CD deployments and application releases.

The HTML file is packaged into the container image during the image build. Kubernetes runs a Pod using that image.

### Deployment workflow

```text
Ubuntu source code (index.html)
          |
          v
Dockerfile COPY -> Build image
          |
          v
Push image to MicroK8s registry
          |
          v
Helm deploys/updates Kubernetes Deployment
          |
          v
Pod runs Nginx with the packaged HTML
```

### Directory structure

```text
nginx-website/
├── app/
│   ├── Dockerfile
│   └── index.html
└── helm/
    └── nginx-website/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── deployment.yaml
            └── service.yaml
```

### app/Dockerfile

```dockerfile
FROM nginx:latest

COPY index.html /usr/share/nginx/html/index.html
```

`COPY` adds the host file to the image at build time.

### Build and push the image

This example uses the MicroK8s registry at `10.206.213.243:32000`:

```bash
docker build \
  -t 10.206.213.243:32000/nginx-website:v1 \
  ./app

docker push 10.206.213.243:32000/nginx-website:v1
```

The registry must be enabled and reachable, and the Docker client must be configured to push to it if it uses an insecure HTTP endpoint.

### helm/nginx-website/Chart.yaml

```yaml
apiVersion: v2
name: nginx-website
description: Nginx website deployment
type: application
version: 0.1.0
appVersion: "1.0"
```

### helm/nginx-website/values.yaml

```yaml
replicaCount: 1

image:
  repository: 10.206.213.243:32000/nginx-website
  tag: v1
  pullPolicy: IfNotPresent

service:
  type: NodePort
  port: 80
  nodePort: 30080
```

### helm/nginx-website/templates/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: nginx
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 80
```

### helm/nginx-website/templates/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ .Release.Name }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80
      nodePort: {{ .Values.service.nodePort }}
```

### Deploy with Helm

```bash
microk8s helm3 upgrade --install nginx-website ./helm/nginx-website \
  -n dev --create-namespace
```

With the example NodePort service, access the site at:

```text
http://10.206.213.243:30080
```

The node IP and NodePort must be reachable from your client.

### Update index.html

After editing `app/index.html`, build and push a new image tag:

```bash
docker build \
  -t 10.206.213.243:32000/nginx-website:v2 \
  ./app

docker push 10.206.213.243:32000/nginx-website:v2
```

Update the Helm release:

```bash
microk8s helm3 upgrade nginx-website ./helm/nginx-website \
  -n dev --set image.tag=v2
```

Check the rollout:

```bash
microk8s kubectl rollout status deployment/nginx-website -n dev
microk8s kubectl get pods -n dev
```

Kubernetes performs a Deployment rollout and replaces old Pods with Pods running the new image, according to the Deployment's update strategy.

**Important:** Use a new image tag for each release where practical. With `IfNotPresent`, reusing a tag can cause a node to use a cached image rather than the image you just pushed. Immutable version tags or image digests make deployments more predictable.

---

## 3. Method B: ConfigMap + Helm

**Best suited to:** non-sensitive configuration and small static files that should be managed separately from the container image.

A ConfigMap stores configuration data in the Kubernetes API server. A Pod can consume that data as environment variables or mounted files.

For this example, the ConfigMap provides `index.html` to Nginx through a volume mount.

### Directory structure

```text
nginx-website/
└── helm/
    └── nginx-website/
        ├── Chart.yaml
        ├── values.yaml
        ├── files/
        │   └── index.html
        └── templates/
            ├── configmap.yaml
            ├── deployment.yaml
            └── service.yaml
```

### helm/nginx-website/templates/configmap.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-html
data:
  index.html: |
{{ .Files.Get "files/index.html" | indent 4 }}
```

` .Files.Get ` reads the file from the Helm chart directory. The template places its contents in the ConfigMap's `data` field.

### Add a volume mount to deployment.yaml

The following shows the relevant Pod specification:

```yaml
spec:
  containers:
    - name: nginx
      image: nginx:latest
      ports:
        - containerPort: 80
      volumeMounts:
        - name: website-content
          mountPath: /usr/share/nginx/html
          readOnly: true
  volumes:
    - name: website-content
      configMap:
        name: {{ .Release.Name }}-html
```

This mounts the ConfigMap at Nginx's web-root directory.

**Important:** Mounting a volume over `/usr/share/nginx/html` hides the directory contents that were originally in the image at that path. In this example, the ConfigMap supplies the website content.

### Deploy with Helm

```bash
microk8s helm3 upgrade --install nginx-website ./helm/nginx-website \
  -n dev --create-namespace
```

### Update index.html

Edit the chart file:

```text
helm/nginx-website/files/index.html
```

Then apply the updated chart:

```bash
microk8s helm3 upgrade nginx-website ./helm/nginx-website -n dev
```

Helm updates the ConfigMap. Kubernetes updates files in a ConfigMap volume eventually; it is not necessarily instantaneous. With a normal ConfigMap volume mount (not `subPath`), the updated file becomes visible without rebuilding the image or restarting the Pod.

Check the ConfigMap:

```bash
microk8s kubectl get configmaps -n dev

microk8s kubectl describe configmap nginx-website-html -n dev
```

**Important ConfigMap notes:**

- ConfigMap volumes are read-only.
- ConfigMaps are for non-sensitive configuration; use Secrets for sensitive values.
- ConfigMaps are intended for relatively small configuration data, not large application datasets.
- A normal ConfigMap volume mount can update eventually. A mount using `subPath` does not receive automatic updates.
- Applications may need to reload configuration themselves after a mounted file changes.
- If a Helm upgrade changes only a ConfigMap, Kubernetes does not necessarily restart the Pods. If the application needs a restart to load the change, configure a Pod-template checksum annotation or trigger a rollout deliberately.

---

## 4. Method C: `kubectl cp` — Manually copy files into a running Pod

**Best suited to:** troubleshooting and one-off manual file transfers.

The Kubernetes equivalent of Docker's `docker cp` is:

```bash
microk8s kubectl cp
```

First, find the Pod:

```bash
microk8s kubectl get pods -n dev
```

Suppose the Pod is named:

```text
nginx-website-xxxxxxxxxx-yyyyy
```

### Copy a file from Ubuntu into the Pod

```bash
microk8s kubectl cp ./index.html \
  dev/nginx-website-xxxxxxxxxx-yyyyy:/usr/share/nginx/html/index.html
```

### Copy an entire directory into the Pod

```bash
microk8s kubectl cp ./website \
  dev/nginx-website-xxxxxxxxxx-yyyyy:/usr/share/nginx/html/
```

### Copy a file from the Pod to Ubuntu

```bash
microk8s kubectl cp \
  dev/nginx-website-xxxxxxxxxx-yyyyy:/usr/share/nginx/html/index.html \
  ./index.html
```

### What happens when index.html changes?

Edit the host file and copy it again:

```bash
nano index.html

microk8s kubectl cp ./index.html \
  dev/nginx-website-xxxxxxxxxx-yyyyy:/usr/share/nginx/html/index.html
```

Normally, no image rebuild or Pod restart is needed.

**Important:**

- `kubectl cp` copies into the container's writable filesystem layer.
- The file normally survives a restart of the container within the same Pod.
- If Kubernetes replaces the Pod, the copied file is lost.
- A Deployment rollout creates replacement Pods, so manual changes are not preserved.
- The target container needs the `tar` executable for `kubectl cp` to work.

A Pod may contain multiple containers. If so, use `-c CONTAINER_NAME` to specify the target container.

---

## 5. Complete comparison

| Feature | Dockerfile `COPY` + Helm | ConfigMap + Helm | `kubectl cp` |
|---|---|---|---|
| File stored in | Container image | Kubernetes ConfigMap | Container writable layer |
| Actual copy? | Yes, at image build | ConfigMap data is mounted as files | Yes |
| Rebuild image after file change? | Yes | No | No |
| Helm upgrade after file change? | Yes, to deploy new image | Yes, to update chart-managed ConfigMap | No |
| Survives Pod replacement? | Yes, in the image | Yes, while ConfigMap exists and is referenced | No |
| Typical use | Application releases | Configuration and small static files | Troubleshooting/manual transfer |

---

## 6. Useful MicroK8s commands

| Command | Purpose |
|---|---|
| `microk8s kubectl get pods -n dev` | List Pods |
| `microk8s kubectl get deployments -n dev` | List Deployments |
| `microk8s kubectl get services -n dev` | List Services |
| `microk8s kubectl get configmaps -n dev` | List ConfigMaps |
| `microk8s kubectl describe pod POD -n dev` | Inspect a Pod |
| `microk8s kubectl logs POD -n dev` | View Pod logs |
| `microk8s kubectl exec -it POD -n dev -- bash` | Open a shell, if Bash is installed |
| `microk8s kubectl cp` | Copy files to/from a Pod |
| `microk8s kubectl rollout status deployment/NAME -n dev` | Check rollout status |
| `microk8s kubectl rollout history deployment/NAME -n dev` | View rollout history |
| `microk8s helm3 list -n dev` | List Helm releases |
| `microk8s helm3 upgrade` | Upgrade a Helm release |
| `microk8s helm3 rollback` | Roll back a Helm release |

---

## 7. Recommended workflow for a DevOps project

### Development

Use local bind mounts with Docker Compose when developing on Ubuntu. This lets you edit files and test them quickly.

### CI/CD and application releases

Use Dockerfile `COPY` to package application files into versioned images. A Gitea Actions pipeline can:

1. Check out source code.
2. Build the Docker image.
3. Tag it with a version or commit identifier.
4. Push it to the container registry.
5. Deploy the new image using Helm.
6. Check the Kubernetes rollout.
7. Roll back to a previous Helm revision/image if needed.

### Configuration management

Use ConfigMaps managed by Helm for non-sensitive configuration and small static files that should be independent of the application image.

Use Kubernetes Secrets or an external secrets solution for sensitive values. Do not put passwords, private keys, or tokens in ConfigMaps.

### Troubleshooting

Use `kubectl cp` for occasional manual file transfers. Do not rely on manual changes inside Pods as the normal deployment process.

---

## 8. Key concepts to remember

- **Dockerfile `COPY`** = package files into the image at build time.
- **ConfigMap** = store non-sensitive configuration in Kubernetes and make it available to Pods.
- **ConfigMap volume** = expose ConfigMap keys as files inside a container.
- **`kubectl cp`** = manually transfer files between Ubuntu and a Pod's container.
- **Image** = reusable application template.
- **Pod** = Kubernetes workload unit that runs one or more containers.
- **Deployment** = manages replicated Pods and rolling updates.
- **Service** = provides a stable network endpoint for selected Pods.
- **Helm** = packages and manages Kubernetes resources as releases.
- **PersistentVolume / PersistentVolumeClaim** = Kubernetes storage abstractions for data that must persist beyond a Pod's lifecycle.

The key distinction: Helm manages Kubernetes resources; Deployments manage Pods; Pods run containers. Container images, ConfigMaps, Secrets, and volumes provide the files and configuration those containers need.
