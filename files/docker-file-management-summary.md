# Docker: Three Ways to Manage Application Files

This guide explains three ways to get `index.html` (or other application files and directories) into a Docker container:

1. **Dockerfile `COPY`** — package files into the Docker image.
2. **Docker Compose bind mounts (`volumes`)** — make host files/directories available inside the container.
3. **`docker cp`** — manually copy files between the host and an existing container.

---

## 1. Dockerfile `COPY` — Build files into the image

**Best suited to:** repeatable builds and CI/CD deployments.

Files copied with `COPY` become part of the Docker image during the image build.

### Example directory structure

```text
nginx-website/
├── Dockerfile
├── index.html
└── compose.yaml
```

### Dockerfile

```dockerfile
FROM nginx:latest

COPY index.html /usr/share/nginx/html/index.html
```

- `FROM` selects the base image.
- `COPY` copies the file from the build context into the image.
- `/usr/share/nginx/html/` is Nginx's default web root.

### compose.yaml

```yaml
services:
  nginx:
    build: .
    container_name: nginx
    ports:
      - "8080:80"
    restart: unless-stopped
```

`build: .` tells Compose to build an image using the current directory as the build context. Docker looks for a `Dockerfile` there by default.

### Commands

```bash
# Build the image and create/start the container
docker compose up -d --build

# List running containers
docker ps

# Follow the service logs
docker compose logs -f nginx

# Rebuild after changing index.html
docker compose up -d --build

# Stop and remove Compose containers and networks
docker compose down
```

### What happens when `index.html` changes?

The host file is not automatically connected to the existing container. Rebuild the image and run Compose again:

```bash
docker compose up -d --build
```

If the image changed, Compose normally replaces the old container with a new one.

- The updated file is packaged into the new image.
- The old container's writable layer and container-local logs are not carried into the new container.
- The previous image may remain locally, depending on its tag and whether it is still referenced.
- Data stored in external bind mounts or named volumes is separate from the container and can survive recreation.

---

## 2. Docker Compose `volumes` — Bind-mount host files/directories

**Best suited to:** local development, where you want host edits to appear in the container without rebuilding.

A bind mount makes a host path available at a path inside the container. It does **not** copy the host file into the image.

### Example directory structure

```text
nginx-website/
├── index.html
└── compose.yaml
```

### Mount one file

```yaml
services:
  nginx:
    image: nginx:latest
    container_name: nginx
    ports:
      - "8080:80"
    volumes:
      - ./index.html:/usr/share/nginx/html/index.html:ro
    restart: unless-stopped
```

### Mount an entire directory instead

```yaml
services:
  nginx:
    image: nginx:latest
    container_name: nginx
    ports:
      - "8080:80"
    volumes:
      - ./website:/usr/share/nginx/html:ro
    restart: unless-stopped
```

For the directory example, the host could contain:

```text
website/
├── index.html
├── about.html
├── style.css
└── images/
    └── logo.png
```

The whole `website` directory is mounted at `/usr/share/nginx/html` inside the container.

### Understanding the mount syntax

```yaml
volumes:
  - ./index.html:/usr/share/nginx/html/index.html:ro
```

- `./index.html` — source file on the Ubuntu host, relative to the Compose file's directory.
- `/usr/share/nginx/html/index.html` — destination path inside the container.
- `ro` — read-only from the container's perspective.

### Commands

```bash
# Create/start the service
docker compose up -d

# Stop containers but keep them
docker compose stop

# Start existing stopped containers
docker compose start

# Restart the service
docker compose restart

# Follow logs
docker compose logs -f nginx

# Stop and remove Compose containers and networks
docker compose down
```

### What happens when `index.html` changes?

Edit the host file:

```bash
nano index.html
```

Save it and refresh the browser. The changed host file is available through the mount; normally no rebuild, container recreation, or restart is needed.

- The file remains on Ubuntu.
- The container sees the mounted file at its destination path.
- Removing/recreating the container does not remove the host file.
- With `:ro`, processes inside the container cannot write to the mounted file.

---

## 3. `docker cp` — Manually copy files into/out of a container

**Best suited to:** one-off file transfers and troubleshooting.

Unlike a bind mount, `docker cp` makes an actual copy. Copying into a container changes its writable filesystem layer, not the image.

### Start an Nginx container

```bash
docker run -d \
  --name nginx \
  -p 8080:80 \
  --restart unless-stopped \
  nginx:latest
```

### Copy a file from Ubuntu into the container

```bash
docker cp ./index.html nginx:/usr/share/nginx/html/index.html
```

### Copy a directory into the container

```bash
docker cp ./website nginx:/usr/share/nginx/html/
```

### Copy a file from the container to Ubuntu

```bash
docker cp nginx:/usr/share/nginx/html/index.html ./index.html
```

### What happens when `index.html` changes?

After editing the host copy, copy it into the container again:

```bash
nano index.html
docker cp ./index.html nginx:/usr/share/nginx/html/index.html
```

Then refresh the browser. Normally no image rebuild or container restart is required.

- The container keeps running.
- Existing container logs remain associated with that container.
- The copied file survives a container restart.
- Removing and recreating the container loses the copied file unless it is copied again.
- Compose has no native `cp:` configuration property, but `docker cp` can be used with a Compose-managed container by specifying its container name or ID.

---

## 4. Comparison

| Feature | Dockerfile `COPY` | Bind mount (`volumes`) | `docker cp` |
|---|---|---|---|
| Where is the file stored? | In the image | On the host; exposed inside the container | In the container's writable layer |
| Copies file? | Yes | No; mounts host path | Yes |
| Host edits automatically visible? | No | Yes | No; copy again |
| Rebuild needed after file changes? | Yes | No | No |
| Container recreation needed after file changes? | Yes, to use a rebuilt image | No | No |
| Survives container restart? | Yes | Yes | Yes |
| Survives container removal? | In the retained image | Yes, on the host | No |
| Typical use | Reproducible builds and deployments | Development and selected runtime configuration | Manual transfer/troubleshooting |

**Important:** A bind mount is not the same thing as a Docker-managed named volume. The examples above use bind mounts because they refer to explicit host paths such as `./index.html` and `./website`.

---

## 5. Useful Docker commands

| Command | Purpose |
|---|---|
| `docker run -d IMAGE` | Run a container in detached/background mode |
| `docker exec -it CONTAINER bash` | Open an interactive Bash shell, if Bash is installed |
| `docker cp SOURCE CONTAINER:DESTINATION` | Copy from host into container |
| `docker cp CONTAINER:SOURCE DESTINATION` | Copy from container to host |
| `docker ps` | List running containers |
| `docker ps -a` | List all containers, including stopped ones |
| `docker images` | List local images |
| `docker logs -f CONTAINER` | Follow container logs |
| `docker stop CONTAINER` | Stop a container |
| `docker start CONTAINER` | Start an existing stopped container |
| `docker restart CONTAINER` | Restart a container |
| `docker rm CONTAINER` | Remove a stopped container |
| `docker compose up -d` | Create/start Compose services in the background |
| `docker compose up -d --build` | Build images and create/start services |
| `docker compose stop` | Stop Compose services without removing containers |
| `docker compose start` | Start existing stopped Compose containers |
| `docker compose down` | Stop and remove Compose containers and networks |
| `docker compose logs -f SERVICE` | Follow logs for a Compose service |
| `docker volume ls` | List Docker-managed volumes |

### Related options

| Option | Meaning |
|---|---|
| `-d` | Detached mode: run in the background |
| `-i` | Keep standard input open |
| `-t` | Allocate a terminal (TTY) |
| `-p HOST_PORT:CONTAINER_PORT` | Publish a container port on the host |
| `-v HOST_PATH:CONTAINER_PATH` | Mount a host path |
| `-w DIRECTORY` | Set the working directory inside the container |
| `-e NAME=value` | Set an environment variable |
| `--name NAME` | Assign a container name |
| `--restart unless-stopped` | Restart automatically unless manually stopped |

---

## 6. Recommended workflow for DevOps

### Development

Use bind mounts when developing locally. Edit files on Ubuntu and test changes in the running container without rebuilding.

### CI/CD

Use a Dockerfile to package the application and its required files into a versioned image. A pipeline can:

1. Check out the source code.
2. Build the image.
3. Tag it with a version or commit identifier.
4. Push it to a container registry.
5. Deploy the new image.
6. Roll back to a previous image version if needed.

### Troubleshooting

Use `docker cp` for occasional manual transfers into or out of an existing container. Avoid relying on manual copies as the normal deployment process because those changes are not part of the image and disappear when the container is removed.

---

## 7. Key concepts to remember

- **Dockerfile `COPY`** = package files into the image at build time.
- **Compose `volumes` (bind mount)** = make host files/directories available inside the container.
- **`docker cp`** = manually copy files between the host and an existing container.
- **Image** = reusable application template.
- **Container** = an instance created from an image.
- **Container recreation** = the old container is replaced; container-local writable data and logs are not automatically transferred.
- **Persistent data** = keep it in bind mounts, named volumes, or external storage rather than relying on a container's writable layer.

For Kubernetes, related concepts include container images, ConfigMaps, Secrets, PersistentVolumes, and PersistentVolumeClaims.
