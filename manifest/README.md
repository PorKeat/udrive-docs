# 📦 Manifest Directory

This directory contains production-ready Kubernetes manifests and the complete UDrive Helm Chart.

---

## 📂 Subdirectories

### 1. [`helm/`](./helm/)
The complete, production-tested Helm chart synchronized directly from the cluster repository (`/home/vuthy/udrive-helm-chart`).
* **`values.yaml`**: Contains 3-node HA configuration, 50MB chunk size, Longhorn RWX persistence, and MinIO S3 backend.
* **`templates/`**: Contains all templated manifests including `deployment.yaml` (with proper NVMe scratch volume mounting order), `service.yaml` (with Traefik stickiness), `idm.yaml`, `nats.yaml`, and `valkey.yaml`.

### 2. [`raw-manifests/`](./raw-manifests/)
Reusable standalone Kubernetes manifests for maintenance and operations:
* **`init-node-scratch.yaml`**: A DaemonSet to automatically create `/var/lib/udrive-uploads` (`1000:1000`, `chmod 775`) on all current or newly added nodes.
* **`import-containerd-image.yaml`**: A one-shot pod definition to import container images into containerd on egress-restricted worker nodes (`node2`/`node3`).
* **`traefik-sticky-service.yaml`**: A standalone service manifest demonstrating Traefik sticky cookie configuration.
