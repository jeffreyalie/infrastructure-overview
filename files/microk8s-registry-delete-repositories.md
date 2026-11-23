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