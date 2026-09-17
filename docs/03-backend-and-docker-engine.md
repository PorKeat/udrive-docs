# 03 - Backend & Docker Engine Guide

This document details the **`udrive-server`** repository, its Go microservices distribution based on ownCloud Infinite Scale (OCIS), the storage engine configuration, and the multi-architecture Docker build pipeline.

---

## 📂 Backend Repository Structure (`udrive-server`)

```text
udrive-server/
├── Dockerfile.production   # Minimal, hardened Alpine-based multi-stage Dockerfile
├── build-docker.sh         # Production multi-arch image builder (Docker Buildx)
├── entrypoint.sh           # Container bootstrap script (chown, permissions, signal handling)
├── ocis/                   # OCIS Go codebase and precompiled binaries
│   └── dist/binaries/
│       ├── ocis-linux-amd64
│       └── ocis-linux-arm64
└── services/
    └── web/
        └── assets/core/    # Embedded web assets copied during container build
```

---

## 🐳 Multi-Arch Docker Build (`build-docker.sh`)

UDrive runs on mixed cluster hardware (x86_64 / AMD64 and ARM64). The image **must** be built as a multi-arch manifest list so Kubernetes can pull and run the native architecture on every worker node.

### Script Options:
```bash
./build-docker.sh [OPTIONS] [IMAGE_TAG]
```

| Flag / Argument | Purpose |
| :--- | :--- |
| `IMAGE_TAG` | Full target image name (e.g. `ghcr.io/unity-workspace-org/udrive:v1.4.15`). |
| `--multiarch` | Builds and pushes manifests for both `linux/amd64` and `linux/arm64`. |
| `--skip-compile` | Skips Go compilation and uses existing binaries in `ocis/dist/binaries/` (fast build). |
| `--clean` | Cleans up previous build artifacts and cache. |

### Example Production Command:
```bash
cd /Users/alexkgm/Desktop/udrive-project/udrive-server

# Build and push v1.4.15 for both amd64 and arm64
./build-docker.sh --multiarch ghcr.io/unity-workspace-org/udrive:v1.4.15 --skip-compile
```

### Under the Hood: Docker Buildx
The script automatically provisions a dedicated containerized buildx builder (`multiarch-builder`):
```bash
docker buildx create --name multiarch-builder --driver docker-container --use
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f Dockerfile.production \
  -t ghcr.io/unity-workspace-org/udrive:v1.4.15 \
  -t ghcr.io/unity-workspace-org/udrive:latest \
  --push .
```

---

## ⚙️ Core Backend Configurations

Key environment variables configured in the Helm chart (`values.yaml`):

### 1. Ingress & Routing
* `OCIS_URL`: `https://drive.unity-workspace.com`
* `PROXY_HTTP_ADDR`: `0.0.0.0:9200`
* `FRONTEND_UPLOAD_MAX_CHUNK_SIZE`: `52428800` (50MB chunks to avoid Cloudflare 413)

### 2. S3 NextGen Storage Driver (MinIO Backend)
* `STORAGE_USERS_DRIVER`: `s3ng`
* `STORAGE_USERS_S3NG_ENDPOINT`: `https://10.1.18.7:9000`
* `STORAGE_USERS_S3NG_REGION`: `default`
* `STORAGE_USERS_S3NG_BUCKET`: `udrive`
* `STORAGE_USERS_S3NG_INSECURE`: `true` (internal cluster TLS)
* `STORAGE_USERS_S3NG_PUT_OBJECT_NUM_THREADS`: `16` (parallel multi-part S3 upload threads)

### 3. Local NVMe Scratch Buffer
* `STORAGE_USERS_S3NG_CACHE_DIRECTORY`: `/var/lib/ocis/storage/users/uploads`
* Backed by Kubernetes `hostPath: /var/lib/udrive-uploads` on local NVMe SSDs.

### 4. Caching & Message Broker
* `CACHE_STORE`: `redis` (pointing to `udrive-valkey:6379`)
* `EVENTS_ENDPOINT`: `127.0.0.1:9233` (embedded NATS broker)
* `THUMBNAILS_RESOLUTIONS`: `64x64,128x128,256x256,512x512,1024x1024`

---

## 🔒 Security & Container Hardening

1. **Non-Root Execution**: Runs as unprivileged user `ocis-user` (`UID 1000`, `GID 1000`).
2. **Minimal Surface Area**: Base image is Alpine Linux with strictly required system packages (`ca-certificates`, `tzdata`, `mailcap`, `curl`).
3. **Graceful Termination**: `entrypoint.sh` traps `SIGTERM` and `SIGINT` signals, giving OCIS workers up to 30 seconds to flush in-flight S3 writes before exiting.
