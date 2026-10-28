# Seaweed Installation and secrets

Table of Contents

* [Installation steps](#installation-setps)
* [Ports used](#how-many-ports-are-used-by-seaweedfs-and-how-can-we-access-via-web-is-there-any-admin-webui-also)
* [Webui setup](#web-access)
* [Secrets used for Webui and GHA](#secrets-for-gha-in-gitea-secret-variables)
---
## Installation setps

### Block 1: install the binary and create the user (skips what already exists)
```bash
if ! command -v weed >/dev/null; then
  cd /tmp
  wget https://github.com/seaweedfs/seaweedfs/releases/latest/download/linux_amd64.tar.gz
  tar xzf linux_amd64.tar.gz
  sudo install -m 755 weed /usr/local/bin/weed
fi
weed version

id seaweedfs >/dev/null 2>&1 || sudo useradd --system --home /var/lib/seaweedfs --shell /usr/sbin/nologin seaweedfs
sudo mkdir -p /var/lib/seaweedfs /etc/seaweedfs
sudo chown seaweedfs:seaweedfs /var/lib/seaweedfs
```
### Block 2: save the keys and write the identity file
This stores the keys in /root/seaweedfs-keys.env (readable only by root) so later blocks work even in a new terminal.
```
echo "ADMIN_ACCESS=$(openssl rand -hex 10)"
echo "ADMIN_SECRET=$(openssl rand -hex 20)"
echo "TF_ACCESS=$(openssl rand -hex 10)"
echo "TF_SECRET=$(openssl rand -hex 20)"
```
```bash
ADMIN_ACCESS=369xxxxxxxxxxxxxxxxxxxxxx
ADMIN_SECRET=369xxxxxxxxxxxxxxxxxxxxxx
TF_ACCESS=369xxxxxxxxxxxxxxxxxxxxxx
TF_SECRET=369xxxxxxxxxxxxxxxxxxxxxx


sudo tee /root/seaweedfs-keys.env > /dev/null <<EOF
ADMIN_ACCESS=$ADMIN_ACCESS
ADMIN_SECRET=$ADMIN_SECRET
TF_ACCESS=$TF_ACCESS
TF_SECRET=$TF_SECRET
EOF
------------
sudo chmod 600 /root/seaweedfs-keys.env
-----------
sudo tee /etc/seaweedfs/s3.json > /dev/null <<EOF
{
  "identities": [
    {
      "name": "admin",
      "credentials": [
        { "accessKey": "$ADMIN_ACCESS", "secretKey": "$ADMIN_SECRET" }
      ],
      "actions": ["Admin", "Read", "Write", "List", "Tagging"]
    },
    {
      "name": "terraform",
      "credentials": [
        { "accessKey": "$TF_ACCESS", "secretKey": "$TF_SECRET" }
      ],
      "actions": ["Read:tfstate", "Write:tfstate", "List:tfstate"]
    }
  ]
}
EOF
---------------
sudo chown root:seaweedfs /etc/seaweedfs/s3.json
sudo chmod 640 /etc/seaweedfs/s3.json
---------------
sudo cat /etc/seaweedfs/s3.json
--------------
```
The last command prints the file. Check that all four key fields are filled in, because an empty key is what crashed the service earlier.

### Block 3: systemd service and start

```bash
sudo tee /etc/systemd/system/seaweedfs.service > /dev/null <<'EOF'
[Unit]
Description=SeaweedFS (master+volume+filer+S3)
After=network-online.target
Wants=network-online.target

[Service]
User=seaweedfs
Group=seaweedfs
ExecStart=/usr/local/bin/weed server \
  -dir=/var/lib/seaweedfs \
  -ip=10.206.213.241 \
  -master.volumeSizeLimitMB=1024 \
  -filer \
  -s3 \
  -s3.config=/etc/seaweedfs/s3.json
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

#---------
sudo systemctl daemon-reload
sudo systemctl enable seaweedfs
sudo systemctl restart seaweedfs
sleep 25
sudo ss -tlnp | grep -E '8333|8888'
sudo systemctl show seaweedfs -p NRestarts
You should see ports 8333 and 8888 listening, and NRestarts=0.
#----------
```
### Block 4: firewall
```bash
sudo ufw allow from 10.206.213.0/24 to any port 8333 proto tcp
```
### Block 5: create the bucket (admin keys)
```bash
sudo snap install aws-cli --classic 2>/dev/null || true
source /root/seaweedfs-keys.env

export AWS_ACCESS_KEY_ID=$ADMIN_ACCESS
export AWS_SECRET_ACCESS_KEY=$ADMIN_SECRET
export AWS_DEFAULT_REGION=us-east-1
EP=http://10.206.213.241:8333

aws --endpoint-url $EP s3 mb s3://tfstate
aws --endpoint-url $EP s3api put-bucket-versioning \
  --bucket tfstate --versioning-configuration Status=Enabled
aws --endpoint-url $EP s3api get-bucket-versioning --bucket tfstate
```
If you see BucketAlreadyOwnedByYou, that's fine, since the bucket already exists.

### Block 6: verify locking and permissions
This uses a fresh key name each time, so a leftover object can't cause a false failure:
```bash
source /root/seaweedfs-keys.env
EP=http://10.206.213.241:8333
export AWS_DEFAULT_REGION=us-east-1
echo a > /tmp/t.txt
K=lock-test-$(date +%s)

echo "--- a) conditional writes: 1st should succeed, 2nd should be PreconditionFailed"
export AWS_ACCESS_KEY_ID=$ADMIN_ACCESS AWS_SECRET_ACCESS_KEY=$ADMIN_SECRET
aws --endpoint-url $EP s3api put-object --bucket tfstate --key $K --body /tmp/t.txt --if-none-match '*'
aws --endpoint-url $EP s3api put-object --bucket tfstate --key $K --body /tmp/t.txt --if-none-match '*'

echo "--- b) terraform key on tfstate: should work"
export AWS_ACCESS_KEY_ID=$TF_ACCESS AWS_SECRET_ACCESS_KEY=$TF_SECRET
aws --endpoint-url $EP s3 ls s3://tfstate/

echo "--- c) terraform key on another bucket: should be AccessDenied"
export AWS_ACCESS_KEY_ID=$ADMIN_ACCESS AWS_SECRET_ACCESS_KEY=$ADMIN_SECRET
aws --endpoint-url $EP s3 mb s3://other-test
export AWS_ACCESS_KEY_ID=$TF_ACCESS AWS_SECRET_ACCESS_KEY=$TF_SECRET
aws --endpoint-url $EP s3 ls s3://other-test/
```
Clean up the scratch buckets afterwards:

```bash
export AWS_ACCESS_KEY_ID=$ADMIN_ACCESS AWS_SECRET_ACCESS_KEY=$ADMIN_SECRET
aws --endpoint-url $EP s3 rb s3://other-test
aws --endpoint-url $EP s3 rb s3://tfstate-test --force
For your Terraform machine, use these credentials (read the TF values from the file on the server):
bash
sudo grep TF_ /root/seaweedfs-keys.env
```
#### Two things to keep in mind:
The admin keys and TF_ACCESS are in this chat. They're on a private LAN, so the risk is low, but I'd rotate all four later by re-running Block 2 with fresh openssl rand values and restarting the service.
The earlier InternalError when writing to a brand-new bucket is still unexplained. If block 6 or a later bucket creation hits it again, run the df -h and journalctl checks from my previous message and send me the output.

---
## How many ports are used by seaweedfs and how can we access via web? is there any admin webui also?

A single-node setup like yours uses 7 ports for the core services, plus 2 more if you add the admin UI.

```
+-------------+-------------------+-----------------------------------+
|  Port       |     Service       |            Purpose                |
+-------------+-------------------+-----------------------------------+
|   8333      |   S3 gateway      |   The S3 API that Terraform uses  |
+---------------------------------------------------------------------+
|   9333      |     Master        |   Cluster management, status page |
+---------------------------------------------------------------------+
|   19333     |   Master gRPC     |   Internal (HTTP port + 10000)    |
+---------------------------------------------------------------------+
|   8080      |   Volume server   |       Stores the data             |
+-------------------------------------------------------------------- +
|   18080     |   Volume gRPC     |         Internal                  |
+-------------------------------------------------------------------- +
|   8888      |      Filer        |     File browser UI and API       |
+-------------------------------------------------------------------- +
|   18888     |    Filer gRPC     | Internal: filer's default pattern |
|             |                   |     not used in this setup        |
+-------------------------------------------------------------------- +
|   23646     |    Admin UI       |       Web admin console           |
|             |   (optional)      |                                   |
+-------------------------------------------------------------------- +
|   33646     |   Admin gRPC         |       Worker connections       |
|             |   (optional)         |     (HTTP port + 10000)        |
+-------------------------------------------------------------------- +
```

Since everything runs on one machine, only 8333 needs to be reachable by Terraform and the Gitea runner.
The rest are internal, and on a single node the gRPC ports only talk to each other locally.
You can confirm what's listening with sudo ss -tlnp | grep weed.

---
## Web access
Master UI at http://10.206.213.241:9333 shows cluster status, topology and volumes.
Filer UI at http://10.206.213.241:8888 is a file browser. Your S3 buckets show up under /buckets/, which is handy for checking tfstate.
Volume server UI at http://10.206.213.241:8080/ui/index.html shows volume statistics.
Admin UI at http://10.206.213.241:23646. Yes, it exists, and it's the most complete one: topology, volumes, file browser, metrics and maintenance tasks. It needs its own service and a password.
8333 is not a web UI. It's the S3 API, so a browser will just show an XML response.

The master, volume and filer UIs have no authentication, so only your own machine should reach them. 
The ufw rule from earlier only opens 8333, so to view the UIs from your desktop, add a rule for just your desktop's IP (replace 10.206.213.50 with it):

```bash
sudo ufw allow from 10.206.213.50 to any port 9333,8888,23646 proto tcp
```
### Setting up the admin UI (run on the server):
```bash
sudo mkdir -p /var/lib/seaweedfs-admin
sudo chown seaweedfs:seaweedfs /var/lib/seaweedfs-admin

sudo tee /etc/seaweedfs/admin.env > /dev/null <<EOF
WEED_ADMIN_USER=admin
WEED_ADMIN_PASSWORD=$(openssl rand -hex 12)
EOF

sudo chown root:seaweedfs /etc/seaweedfs/admin.env
sudo chmod 640 /etc/seaweedfs/admin.env

sudo tee /etc/systemd/system/seaweedfs-admin.service > /dev/null <<'EOF'
[Unit]
Description=SeaweedFS Admin UI
After=seaweedfs.service
Requires=seaweedfs.service

[Service]
User=seaweedfs
Group=seaweedfs
EnvironmentFile=/etc/seaweedfs/admin.env
ExecStart=/usr/local/bin/weed admin \
  -master=10.206.213.241:9333 \
  -ip=10.206.213.241 \
  -port=23646 \
  -dataDir=/var/lib/seaweedfs-admin
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now seaweedfs-admin
sudo cat /etc/seaweedfs/admin.env
```
The last command prints the generated password. Then open http://10.206.213.241:23646 and log in as admin with that password. 
I used the server's IP for -master instead of localhost because your master is listening on that address.

---

## Secrets for GHA in gitea secret variables

What secrets and variable should I use for GHA and terraform tf files. and what secrets to add in repo Settings → Secrets and Variables level. and how backend block to use?
Setting up Gitea Actions secrets and variables configuration.
Setting up Gitea Actions secrets and variables configuration.
You need two secrets and, optionally, a few variables. The backend block holds no credentials.

1. Repo secrets
In Gitea this is under the repo’s Settings → Actions → Secrets (on GitHub it’s Settings → Secrets and variables → Actions). 
Add:
```
----------------------------------------
Name                  Value
----------------------------------------
S3_ACCESS_KEY       your TF_ACCESS value
S3_SECRET_KEY       your TF_SECRET value
-----------------------------------------
```
Use only the Terraform pair here. Never put the admin pair in a repo.

2. Repo variables

These aren’t sensitive, so use Settings → Actions → Variables:
```
---------------------------------------------
Name                      Value
S3_ENDPOINT     http://10.206.213.241:8333
S3_BUCKET                 tfstate
--------------------------------------------
```

Backend blocks can’t read variables directly, so these only help if you pass them with -backend-config (see below). `
The simplest option is to hardcode them in the backend block and skip the variables entirely, since a private IP and a bucket name aren’t secrets.

### Used for GHA:
TF_ACCESS=bafd89b41f6b0db671dd
TF_SECRET=369xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
### Used for webui access       
WEED_ADMIN_USER=admin
WEED_ADMIN_PASSWORD=369xxxxxxxxxxxxxxxxxxxx

