# Listing Images in the MicroK8s Container Registry

This guide shows how to list repositories and image tags stored in the
MicroK8s registry.

Registry endpoint used in this lab:

``` text
http://10.206.213.243:32000
```

## Prerequisites

Run these commands from a machine that can reach the registry. The
examples use `curl` and `jq`.

Check that the registry is reachable:

``` bash
curl -s http://10.206.213.243:32000/v2/
```

A successful response is commonly an empty JSON object:

``` json
{}
```

## 1. List all repositories

The Registry HTTP API endpoint `/_catalog` lists repositories:

``` bash
curl -s http://10.206.213.243:32000/v2/_catalog | jq
```

Example output:

``` json
{
  "repositories": [
    "kubernetes-app-nginx",
    "grafan-lxd-monitoring"
  ]
}
```

## 2. List tags for one repository

Use the repository's `tags/list` endpoint. For the Nginx application:

``` bash
curl -s http://10.206.213.243:32000/v2/kubernetes-app-nginx/tags/list | jq
```

Example output:

``` json
{
  "name": "kubernetes-app-nginx",
  "tags": [
    "v1",
    "v2",
    "v3",
    "v4"
  ]
}
```

## 3. List every repository and its tags

This loop retrieves the repository catalog, then lists the tags for each
repository:

``` bash
for repo in $(curl -s http://10.206.213.243:32000/v2/_catalog | jq -r '.repositories[]'); do
    echo "Repository: $repo"
    curl -s "http://10.206.213.243:32000/v2/$repo/tags/list" | jq -r '.tags[]'
    echo "------------------------"
done
```

Example output:

``` text
Repository: kubernetes-app-nginx
v1
v2
v3
v4
------------------------
Repository: grafan-lxd-monitoring
latest
------------------------
```

## 4. Understand the difference

  Command or endpoint                What it lists
  ---------------------------------- --------------------------------------------
  `GET /v2/_catalog`                 Repositories stored in the registry
  `GET /v2/<repository>/tags/list`   Tags available for a repository
  `docker images`                    Images cached locally by the Docker daemon

**Important:** `docker images` does not show everything pushed to the
registry. Use the Registry API endpoints above to inspect the registry
contents.

## 5. Check your Kubernetes Deployments
You can list all deployed container images:
```bash
kubectl get deployments -A \
  -o custom-columns='NAMESPACE:.metadata.namespace,DEPLOYMENT:.metadata.name,IMAGES:.spec.template.spec.containers[*].image'
```

This helps identify which deployments reference your registry images.

## Notes

-   Replace `10.206.213.243:32000` if your registry endpoint changes.
-   These commands list repositories and tags; they do not show a
    chronological history of every `docker push`.
-   The registry catalog and tag-list endpoints may be paginated on
    registries with many entries. The simple commands above are suitable
    for a small lab registry.
-   This lab registry currently uses HTTP. For a TLS-enabled registry,
    use its HTTPS endpoint and configure certificate trust as
    appropriate.
