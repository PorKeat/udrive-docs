# 🛠️ UDrive Setup & Deployment Playbook

This directory contains step-by-step procedural guides for provisioning, configuring, and verifying the production high-availability UDrive cluster.

---

## 📑 Setup Sequence

| Step | Guide | Description |
| :--- | :--- | :--- |
| **01** | [01 - Node Prerequisites](01-node-prerequisites.md) | OS preparation, kernel parameters, local NVMe upload mount points (`/mnt/udrive-uploads`), and required packages. |
| **02** | [02 - Offline Image Caching](02-offline-image-caching.md) | Air-gap container image loading onto isolated worker nodes (`node2`, `node3`) via `ctr image import`. |
| **03** | [03 - HashiCorp Vault & MinIO Configuration](03-vault-and-minio-config.md) | Setting up HashiCorp Vault KV v2 secret paths and MinIO S3 credentials for production storage. |
| **04** | [04 - Helm Installation & HA Verification](04-helm-installation.md) | Helm chart deployment, Longhorn RWX storage binding, and 3-node HA failover verification. |

---

> [!NOTE]
> All manifests and templates required by these guides are located in the adjacent [`manifest/`](../manifest/) directory.
