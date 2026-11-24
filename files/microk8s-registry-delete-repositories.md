# Script: delete only specified tags

```bash
#!/bin/bash
set -euo pipefail

REGISTRY="http://10.206.213.243:32000"
REPO="kubernetes-app-nginx"

# Add only the tags you want to delete
DELETE_TAGS=(
    "V4"
    "V9"
    "v4"
    "V3"
    "V6"
    "v3"
    "Vv1"
    "V7"
    "V5"
    "V8"
)

# true = preview only
# false = actually delete
DRY_RUN=true

ACCEPT="application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json"

for tag in "${DELETE_TAGS[@]}"; do

    echo "Processing tag: $tag"

    digest=$(curl -fsSI \
        -H "Accept: $ACCEPT" \
        "$REGISTRY/v2/$REPO/manifests/$tag" |
        awk 'tolower($1)=="docker-content-digest:" {
            gsub("\r", "", $2)
            print $2
            exit
        }')

    if [[ -z "$digest" ]]; then
        echo "ERROR: Could not retrieve digest for $tag"
        exit 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY RUN: Would delete $tag -> $digest"
    else
        status=$(curl -sS -o /dev/null -w "%{http_code}" \
            -X DELETE \
            "$REGISTRY/v2/$REPO/manifests/$digest")

        if [[ "$status" == "202" ]]; then
            echo "DELETED: $tag"
        else
            echo "ERROR: HTTP $status while deleting $tag"
            exit 1
        fi
    fi

    echo "-----------------------------"
done

echo "Finished."

```
## Check your Kubernetes Deployments
You can list all deployed container images:
```bash
kubectl get deployments -A \
  -o custom-columns='NAMESPACE:.metadata.namespace,DEPLOYMENT:.metadata.name,IMAGES:.spec.template.spec.containers[*].image'
```
## Get the list also
```bash
curl -s http://10.206.213.243:32000/v2/kubernetes-app-nginx/tags/list | jq
```

## How to use it
| Setting | Behavior |
| ------- | -------- |
| DELETE_TAGS | Only these tags are targeted |
| DRY_RUN=true | Preview, no deletion |
| DRY_RUN=false | Execute deletion |

For example, if tomorrow you want to delete only v3 and V5, change the array to:
```bash
DELETE_TAGS=(
    "v3"
    "V5"
)
```

## Verify the registry
```bash
curl -s http://10.206.213.243:32000/v2/kubernetes-app-nginx/tags/list | jq
```
You should retain v1 and v2 after deleting the ten specified tags.

**One safety note:** This script assumes each targeted digest is not also referenced by an unlisted tag. Before executing, check for shared digests across all tags, as discussed earlier. The registry API deletes by digest, not by tag name.

## Check the deployemnet, repository , tag and pod firts

```bash
#!/usr/bin/env bash
# registry-pods.sh: repository, tag, deployment, pod
NODE="${NODE:-10.206.213.243}"
REG="$NODE:32000"

# Pods: "repo:tag<TAB>namespace/pod"
kubectl get pods -A -o json | jq -r '
  .items[] | . as $p
  | (.spec.initContainers[]?, .spec.containers[]?)
  | select(.image | test(":32000/"))
  | (.image | sub("^[^/]*:32000/"; "")
      | if test("@") or test(":[^/]*$") then . else . + ":latest" end) as $img
  | "\($img)\t\($p.metadata.namespace)/\($p.metadata.name)"' | sort -u > /tmp/pod_images.tsv

# Deployments: "repo:tag<TAB>namespace/deployment" (read from the pod template, so replicas=0 is included)
kubectl get deployments -A -o json | jq -r '
  .items[] | . as $d
  | (.spec.template.spec.initContainers[]?, .spec.template.spec.containers[]?)
  | select(.image | test(":32000/"))
  | (.image | sub("^[^/]*:32000/"; "")
      | if test("@") or test(":[^/]*$") then . else . + ":latest" end) as $img
  | "\($img)\t\($d.metadata.namespace)/\($d.metadata.name)"' | sort -u > /tmp/deploy_images.tsv

# {
#   echo -e "REPOSITORY\tTAG\tDEPLOYMENT\tPOD"
#   for repo in $(curl -s "http://$REG/v2/_catalog?n=1000" | jq -r '.repositories[]'); do
#     for tag in $(curl -s "http://$REG/v2/$repo/tags/list" | jq -r '.tags[]?'); do
#       deps=$(awk -F'\t' -v k="$repo:$tag" '$1==k {print $2}' /tmp/deploy_images.tsv | paste -sd, -)
#       pods=$(awk -F'\t' -v k="$repo:$tag" '$1==k {print $2}' /tmp/pod_images.tsv | paste -sd, -)
#       echo -e "$repo\t$tag\t${deps:-none}\t${pods:-none}"
#     done | sort
#   done
# } | column -t -s$'\t'

{
  echo -e "DEPLOYMENT\tREPOSITORY\tTAG\tPOD"
  for repo in $(curl -s "http://$REG/v2/_catalog?n=1000" | jq -r '.repositories[]'); do
    for tag in $(curl -s "http://$REG/v2/$repo/tags/list" | jq -r '.tags[]?'); do
      awk -F'\t' -v k="$repo:$tag" -v repo="$repo" -v tag="$tag" '
        FNR==NR { if ($1==k) dep[++nd]=$2; next }
        $1==k   { pod[++np]=$2 }
        END {
          n=0
          # pair each deployment with the pods it owns (pod = deployment-<hash>-<suffix>)
          for (i=1; i<=nd; i++) {
            m=0
            for (j=1; j<=np; j++)
              if (!used[j] && pod[j] ~ ("^" dep[i] "-[a-z0-9]+-[a-z0-9]+$")) {
                used[j]=1; rows[++n]=dep[i] "\t" pod[j]; m++
              }
            if (!m) rows[++n]=dep[i] "\tnone"
          }
          # pods not owned by a listed deployment
          for (j=1; j<=np; j++) if (!used[j]) rows[++n]="none\t" pod[j]
          if (n==0) rows[++n]="none\tnone"
          for (r=1; r<=n; r++) {
            split(rows[r], f, "\t")
            print f[1] "\t" repo "\t" tag "\t" f[2]
          }
        }' /tmp/deploy_images.tsv /tmp/pod_images.tsv
    done
  done
} | column -t -s$'\t'






# #!/usr/bin/env bash
# # registry-pods.sh: repository, tag, pod
# NODE="${NODE:-10.206.213.243}"
# REG="$NODE:32000"
#
# # Pods using images from this registry: "repo:tag<TAB>pod" (init containers included)
# # The registry prefix (localhost:32000, node IP, etc.) is stripped; untagged -> :latest
# kubectl get pods -A -o json | jq -r '
#   .items[] | . as $p
#   | (.spec.initContainers[]?, .spec.containers[]?)
#   | select(.image | test(":32000/"))
#   | (.image | sub("^[^/]*:32000/"; "")
#       | if test("@") or test(":[^/]*$") then . else . + ":latest" end) as $img
#   | "\($img)\t\($p.metadata.name)"' | sort -u > /tmp/pod_images.tsv
#
# {
#   echo -e "REPOSITORY\tTAG\tPOD"
#   for repo in $(curl -s "http://$REG/v2/_catalog?n=1000" | jq -r '.repositories[]'); do
#     for tag in $(curl -s "http://$REG/v2/$repo/tags/list" | jq -r '.tags[]?'); do
#       pods=$(awk -F'\t' -v k="$repo:$tag" '$1==k {print $2}' /tmp/pod_images.tsv | paste -sd, -)
#       echo -e "$repo\t$tag\t${pods:-none}"
#     done | sort
#   done
# } | column -t -s$'\t'
```