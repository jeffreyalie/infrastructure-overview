# MicroK8s Registry: Current HTTP Configuration and Future HTTPS Migration

This document records the current registry setup in the lab and the
planned path to secure it with HTTPS later.

## 1. Current lab architecture

The MicroK8s built-in registry is currently accessed over **HTTP**, not
HTTPS.

Registry endpoint:

``` text
10.206.213.243:32000
```

The same registry is used for both image pushes and Kubernetes image
pulls:

``` text
Laptop / Gitea Actions runner
        |
        | Docker push over HTTP
        v
MicroK8s registry: 10.206.213.243:32000
        ^
        | Kubernetes image pull over HTTP
        |
MicroK8s containerd
```

The registry server itself must support the protocol being used. In this
lab, the MicroK8s registry addon is currently serving HTTP.

## 2. Docker on the laptop: allow HTTP registry access

Docker normally expects registry connections to use HTTPS. To allow the
laptop's Docker daemon to push to this HTTP registry, the registry is
configured as an **insecure registry** in Docker's daemon configuration.

File:

``` text
/etc/docker/daemon.json
```

Example:

``` json
{
  "insecure-registries": [
    "10.206.213.243:32000"
  ]
}
```

After changing Docker daemon configuration, restart Docker:

``` bash
sudo systemctl restart docker
```

Check the Docker daemon's effective configuration:

``` bash
docker info | grep -A5 "Insecure Registries"
```

Example push:

``` bash
docker push 10.206.213.243:32000/kubernetes-app-nginx:v1
```

**Important:** Docker's `insecure-registries` setting allows Docker to
communicate with that registry over HTTP (or use insecure TLS). It does
not make the registry HTTPS-enabled. The connection in this lab is HTTP.

If a Gitea Actions runner uses a different Docker daemon, that daemon
may need its own equivalent configuration. The laptop's
`/etc/docker/daemon.json` does not automatically configure a separate
runner Docker daemon.

## 3. MicroK8s containerd: allow HTTP image pulls

Kubernetes does not use the laptop's Docker daemon to pull images.
MicroK8s uses **containerd** as its container runtime.

The MicroK8s containerd CRI plugin is configured to read
registry-specific settings from:

``` text
/var/snap/microk8s/current/args/certs.d/
```

The containerd template includes a registry configuration path similar
to:

``` toml
[plugins."io.containerd.grpc.v1.cri".registry]
  config_path = "${SNAP_DATA}/args/certs.d"
```

For a registry endpoint, containerd can use a matching directory
containing a `hosts.toml` file. For example, the configuration for this
registry endpoint would be stored under:

``` text
/var/snap/microk8s/current/args/certs.d/10.206.213.243:32000/hosts.toml
```

Example HTTP configuration:

``` toml
server = "http://10.206.213.243:32000"

[host."http://10.206.213.243:32000"]
  capabilities = ["pull", "resolve"]
```

This tells containerd how to contact that specific registry endpoint
using HTTP for image pulls and manifest resolution.

After changing MicroK8s containerd registry configuration, restart
MicroK8s if required for the configuration to be applied:

``` bash
sudo snap restart microk8s
microk8s status --wait-ready
```

Then test by deploying a Pod that references an image in the registry. A
successful `ctr images pull` command by itself is not conclusive proof
that Kubernetes/CRI image pulls are configured correctly; test with an
actual Kubernetes workload too.

**Important:** The `certs.d` directory is for MicroK8s containerd, not
Docker on the laptop. Docker and containerd have separate registry
configuration.

## 4. Current configuration summary

  -------------------------------------------------------------------------------------------
  Component               Purpose                 Current protocol/configuration
  ----------------------- ----------------------- -------------------------------------------
  MicroK8s built-in       Stores container images HTTP
  registry                                        

  Laptop Docker daemon    Pushes images to        HTTP allowed using `insecure-registries` in
                          registry                `/etc/docker/daemon.json`

  MicroK8s containerd     Pulls images for        HTTP configured per registry using
                          Kubernetes Pods         `certs.d/<registry>/hosts.toml`

  Kubernetes workloads    Request images through  Image references point to
                          the node's container    `10.206.213.243:32000/<repository>:<tag>`
                          runtime                 
  -------------------------------------------------------------------------------------------

The Docker and containerd settings are client-side configuration. They
do not enable TLS on the registry server.

## 5. Future improvement: migrate the registry to HTTPS

For a more secure setup, the registry should eventually be served over
HTTPS with a valid TLS certificate.

The future architecture will look like this:

``` text
Laptop Docker daemon
        |
        | HTTPS with certificate validation
        v
TLS-enabled container registry
        ^
        | HTTPS with certificate validation
        |
MicroK8s containerd
```

The migration will involve these main steps:

1.  **Enable HTTPS on the registry server.** Configure the registry
    service, or a suitable TLS-terminating reverse proxy, with a server
    certificate and its private key.
2.  **Establish certificate trust.** If the certificate is issued by a
    private CA, install/configure that CA certificate for the Docker
    daemon and MicroK8s containerd. If using a publicly trusted
    certificate, ensure the clients have the necessary trust chain.
3.  **Configure Docker.** Remove the registry from `insecure-registries`
    once HTTPS and certificate validation are working. Docker should
    connect using the HTTPS registry endpoint.
4.  **Configure containerd.** Update the registry's `hosts.toml` to use
    HTTPS and configure the CA trust if required.
5.  **Update image references if the registry endpoint changes.** Keep
    the same hostname/IP and port if possible; otherwise update the
    image repository in Helm values and CI/CD workflows.
6.  **Test the full pipeline.** Verify Docker push, Kubernetes image
    pull, and a Helm deployment using the HTTPS endpoint.

### Certificate roles

  -----------------------------------------------------------------------
  Certificate/file        Purpose                 Where it is used
  ----------------------- ----------------------- -----------------------
  Server certificate      Identifies the HTTPS    Registry server
  (`tls.crt`)             registry server         

  Server private key      Proves the server's     Registry server only;
  (`tls.key`)             identity during TLS     keep secret

  CA certificate          Allows clients to       Docker and/or
  (`ca.crt`)              verify a certificate    containerd clients, as
                          issued by a private CA  appropriate
  -----------------------------------------------------------------------

Do not copy the registry server's private key to the MicroK8s node or
laptop. Clients need to trust the issuing CA or certificate; they do not
need the server's private key.

## 6. Important distinction

-   **HTTP** means traffic is not encrypted and the server identity is
    not verified through TLS.
-   **HTTPS** means traffic is protected by TLS, provided clients
    validate the server certificate.
-   Docker's `insecure-registries` setting does not enable HTTPS. It
    allows Docker to use an insecure registry connection.
-   Containerd's `hosts.toml` tells containerd how to connect to a
    registry; it does not configure the registry server to provide
    HTTPS.
-   Enabling HTTPS requires a change on the registry server as well as
    appropriate trust/configuration on each client.

## 7. Recommended learning sequence

For this lab, keep the current HTTP setup while learning and validating
the complete CI/CD workflow:

``` text
Gitea Actions
    -> Docker build
    -> Docker push to MicroK8s registry
    -> Helm deployment
    -> Kubernetes / containerd image pull
    -> Running Pod
```

Once this pipeline is working reliably, migrate the registry to HTTPS as
a separate improvement. This keeps the current learning task manageable
and makes it easier to troubleshoot each change.
