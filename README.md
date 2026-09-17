# 🚀 UDrive Enterprise Documentation & Deployment Kit

This repository contains the complete production-grade technical documentation, developer setup guides, release runbooks, and Kubernetes manifests for **UDrive** (ownCloud Infinite Scale customized for the Unity Workspace ecosystem).

Engineered with 3-node High Availability (HA), ultra-fast local NVMe scratch storage, and Cloudflare upload optimizations.

---

## 📂 Directory Organization

```text
udrive-docs/
├── docs/              # In-depth architectural, developer, release, and operational guides
├── setup/             # Sequential step-by-step infrastructure installation & config guides
└── manifest/          # Production Helm chart & standalone Kubernetes YAMLs
```

---

## 🧭 Complete Documentation Index

### 📘 Architecture, Development & Operations ([`docs/`](./docs/README.md))
1. [**01 - Architecture & System Design**](./docs/01-architecture-and-system-design.md): 3-node HA topology, 3-tier storage engine (NVMe + Longhorn + MinIO), zero SPOF, and OCIS microservices.
2. [**02 - Codebase & Frontend Developer Guide**](./docs/02-codebase-and-frontend-guide.md): `udrive-web` pnpm monorepo structure, App Switcher, Profile dropdown admin settings, and stuck processing files UX.
3. [**03 - Backend & Docker Engine Guide**](./docs/03-backend-and-docker-engine.md): `udrive-server`, S3NG storage driver, multi-arch Docker build (`build-docker.sh`), and environment configurations.
4. [**04 - Local Development & Setup**](./docs/04-local-development-and-setup.md): Step-by-step local setup, pnpm workspace installation, Vite HMR, and backend proxy configuration.
5. [**05 - Build & Release Pipeline Runbook**](./docs/05-build-and-release-pipeline.md): Verified production release runbook: frontend build -> multi-arch Docker image -> Helm chart packaging -> Kubernetes rollout.
6. [**06 - Upload Pipeline & Cloudflare Optimization**](./docs/06-upload-pipeline-and-cloudflare.md): Cloudflare 100MB body limit, 50MB deterministic chunking, and Traefik sticky sessions (`udrive_sticky`).
7. [**07 - Media Streaming, Previews & Office Integration**](./docs/07-media-streaming-preview-and-office.md): Video formats (`.mov` vs `.mp4`, `+faststart`), Collabora Online Office integration, and client error diagnostics.
8. [**08 - Operations, Maintenance & Troubleshooting**](./docs/08-operations-maintenance-and-troubleshooting.md): Day-2 health checks, NVMe scratch cleanup, recovering stuck files, Longhorn recovery, and Helm rollback.

---

### ⚙️ Cluster Setup & Infrastructure ([`setup/`](./setup/README.md))
* [**01 - Node Prerequisites**](./setup/01-node-prerequisites.md): Host scratch storage initialization and permissions (`1000:1000`, `chmod 775`).
* [**02 - Offline Image Caching**](./setup/02-offline-image-caching.md): Exporting and caching container images across restricted nodes.
* [**03 - Vault & MinIO Setup**](./setup/03-vault-and-minio-config.md): Vault Kubernetes auth role, secrets, and MinIO S3 bucket setup.
* [**04 - Helm Installation**](./setup/04-helm-installation.md): Step-by-step initial Helm deployment, validation, rollout, and rollback.

---

### 📦 Manifests & Helm Chart ([`manifest/`](./manifest/README.md))
* **[`manifest/helm/`](./manifest/helm/)**: Production Helm chart (synchronized with `udrive-helm-chart` v0.3.26 / udrive v1.4.15).
  * `values.yaml`: Configured with 3-node HA, pod anti-affinity, 50MB chunking, and MinIO S3 backend.
  * `templates/`: Production templates with verified volume mount ordering and Traefik sticky cookies.
* **[`manifest/raw-manifests/`](./manifest/raw-manifests/)**:
  * `init-node-scratch.yaml`: One-shot DaemonSet to initialize `/var/lib/udrive-uploads`.
  * `import-containerd-image.yaml`: Pod manifest to import images into containerd on offline/firewalled nodes.
  * `traefik-sticky-service.yaml`: Standalone Traefik sticky session service example.

---

## ⚡ Cluster Quick Reference

| Resource | Value / Endpoint |
| :--- | :--- |
| **Public Production URL** | [https://drive.unity-workspace.com](https://drive.unity-workspace.com) |
| **Office Online (Collabora)** | [https://office.unity-workspace.com](https://office.unity-workspace.com) |
| **Cluster Nodes** | `node1` (`10.1.16.11`), `node2` (`10.1.16.12`), `node3` (`10.1.16.13`) |
| **Kubernetes Namespace** | `udrive` |
| **Helm Release Name** | `udrive` |
| **MinIO S3 Distributed** | `https://10.1.18.7:9000` (bucket: `udrive`) |
| **Vault Server** | `https://10.1.18.8:8200` |
| **Container Registry** | `ghcr.io/unity-workspace-org/udrive` |
