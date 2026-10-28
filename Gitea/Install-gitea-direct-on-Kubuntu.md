# Install gitea on Ubuntu

## Step 1: Install Dependencies & Create git System User

Install Git, SQLite, and Nginx (which will act as the HTTP reverse proxy to route [http://gitea.local](http://gitea.local) to Gitea's internal service):
```Bash
sudo apt update
sudo apt install -y git sqlite3 nginx wget curl
```
Create a dedicated system user and group for running Gitea safely:
```Bash
sudo adduser --system --shell /bin/bash --gecos 'Git Version Control' --group --disabled-password --home /home/git git
```

## Step 2: Download and Install Gitea Binary
Fetch the latest Gitea release binary, move it to /usr/local/bin, and make it executable:
Bash
Fetch latest release tag version
```
GITEA_VER=$(curl -fsSL https://dl.gitea.com/version.json | grep -oP '"latest":\s*\{\s*"version":\s*"\K[^"]+' || echo "28.1.0")
```
Download binary
```
sudo wget -O /usr/local/bin/gitea "https://dl.gitea.com/gitea/${GITEA_VER}/gitea-${GITEA_VER}-linux-amd64"
```
Set executable permission
```
sudo chmod +x /usr/local/bin/gitea
```

## Step 3: Create Gitea Directory Structure
Set up Gitea storage directories and adjust access rights:
```Bash
sudo mkdir -p /var/lib/gitea/{custom,data,indexers,public,log}
sudo chown -R git:git /var/lib/gitea/
sudo chmod -R 750 /var/lib/gitea/

sudo mkdir /etc/gitea
sudo chown root:git /etc/gitea
sudo chmod 770 /etc/gitea
```
## Step 4 (Updated): Create and Enable Systemd Service

1. Write the gitea.service file directly
Run this command in your terminal to create /etc/systemd/system/gitea.service:
```Bash
sudo cat <<'EOF' | sudo tee /etc/systemd/system/gitea.service
[Unit]
Description=Gitea (Git with a cup of tea)
After=syslog.target
After=network.target

[Service]
Type=simple
User=git
Group=git
WorkingDirectory=/var/lib/gitea/
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea

[Install]
WantedBy=multi-user.target
EOF
```
(Alternatively, if you prefer downloading from GitHub, use the master branch link: sudo wget [https://raw.githubusercontent.com/go-gitea/gitea/master/contrib/systemd/gitea.service](https://raw.githubusercontent.com/go-gitea/gitea/master/contrib/systemd/gitea.service) -O /etc/systemd/system/gitea.service)

2. Reload Systemd and Start Gitea
Now that the unit file exists, reload the daemon and enable the service:
```Bash
sudo systemctl daemon-reload
sudo systemctl enable --now gitea
```
3. Verify Service Status
Check that Gitea is active and running:
```Bash
sudo systemctl status gitea
```
Once confirmed, you can proceed directly to Step 5 (configuring /etc/hosts for gitea.local) and Step 6 (setting up Nginx reverse proxy).

## Step 5: Map gitea.local Domain Locally
Add a local DNS mapping in your /etc/hosts file so your laptop resolves gitea.local to loopback:
```Bash
echo "127.0.0.1 gitea.local" | sudo tee -a /etc/hosts
```
## Step 6: Configure Nginx Reverse Proxy (Port 80)
Configure Nginx to listen on standard HTTP port 80 for gitea.local requests and forward them to Gitea's internal port (3000):
Create a new Nginx virtual host configuration file:
```Bash
sudo nano /etc/nginx/sites-available/gitea
Or 
sudo vi etc/nginx/sites-available/gitea
```
Paste the following configuration:
```
Nginx
server {
    listen 80;
    server_name gitea.local;

    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable the site and restart Nginx:
```Bash
sudo ln -s /etc/nginx/sites-available/gitea /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Step 7: Complete Initial Web Setup
Open your browser and navigate to http://gitea.local.

Fill in the installation form settings:
```
Database Type: SQLite3
Path: /var/lib/gitea/data/gitea.db
Server Domain: gitea.local
Gitea Base URL: [http://gitea.local/](http://gitea.local/)
SSH Server Port: 22
Expand Administrator Account Settings to register your main admin credentials.
Click Install Gitea.
Step 8: Secure Configuration File Permissions
Lock down permissions on the generated configuration file after completing setup:
Bash
sudo chmod 750 /etc/gitea
sudo chmod 640 /etc/gitea/app.ini
```
---
