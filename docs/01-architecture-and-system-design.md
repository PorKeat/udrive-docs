# 01 - Architecture & System Design

This document details the architectural topology, multi-node High Availability (HA) design, microservices structure, and 3-tier storage engine powering **UDrive** (ownCloud Infinite Scale customized for the Unity Workspace ecosystem).

---

## 🏗️ High-Level System Topology

UDrive is deployed on a 3-node Kubernetes cluster. It is engineered with **zero Single Point of Failure (SPOF)**: if any node experiences a hardware failure, network partition, or reboot, the remaining nodes maintain full service availability.

```
                  +-----------------------------------+
                  |   Users / Web Clients / Desktop   |
                  +-----------------+-----------------+
                                    |
                            [ Cloudflare Proxy ]
                        (100MB Max Payload, SSL/TLS)
                                    |
                    +---------------+---------------+
                    |  Traefik Ingress Controller   |
                    |  (Sticky Sessions: udrive_sticky)
                    +---------------+---------------+
                                    |
            +-----------------------+-----------------------+
            |                       |                       |
      [ Node 1 ]              [ Node 2 ]              [ Node 3 ]
   10.1.16.11 (NVMe)       10.1.16.12 (NVMe)       10.1.16.13 (NVMe)
            |                       |                       |
    +-------+-------+       +-------+-------+       +-------+-------+
    | udrive replica|       | udrive replica|       | udrive replica|
    | udrive-idm    |       | udrive replica|       | udrive replica|
    | udrive-nats   |       |               |               |
    | udrive-valkey |       |               |               |
    +---------------+       +---------------+       +---------------+
            \                       |                      /
             \                      |                     /
     ===============================================================
                     3 - T I E R   S T O R A G E
     ===============================================================
     Tier 1: Local NVMe SSD Host Scratch  (/var/lib/udrive-uploads)
     Tier 2: Longhorn RWX Replicated PVCs (udrive-data, udrive-config)
     Tier 3: MinIO S3 Distributed Bucket  (https://10.1.18.7:9000/udrive)
```

---

## 📦 Repositories Overview

The UDrive ecosystem is divided across four git repositories under the GitHub organization `unity-workspace-org`:

| Repository | Tech Stack | Role & Responsibility |
| :--- | :--- | :--- |
| **`udrive-web`** | Vue 3, Vite, TypeScript, Pinia, pnpm | Custom Web UI, Unity Workspace App Switcher, Profile dropdown admin settings, file previewers, WebDAV handling. |
| **`udrive-server`** | Go, Alpine Linux, Docker, Docker Buildx | Custom OCIS backend distribution, multi-arch Docker image packaging (`linux/amd64` & `linux/arm64`). |
| **`udrive-helm-chart`**| Helm 3, Kubernetes YAML | Production Kubernetes deployment manifests, HPA, Traefik sticky routing, volume mounts, secret management. |
| **`udrive-docs`** | Markdown, Kubernetes manifests | Centralized technical knowledge base, architecture specs, developer onboarding guides, and operational runbooks. |

---

## 💾 The 3-Tier Storage Model

Enterprise file platforms face competing demands:
1. Uploading massive multi-gigabyte files requires **maximum IOPS and sequential write speed (>1,000 MB/s)** without network latency.
2. Metadata, folder hierarchies, and user sessions require **high consistency and disaster recovery replication**.
3. Long-term file storage requires **infinitely scalable, cost-effective object storage**.

UDrive resolves this with a specialized **3-Tier Storage Architecture**:

| Storage Tier | Technology | Mount Path / Location | Performance Profile | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1: In-Flight Scratch** | Local PCIe NVMe SSD (`hostPath`) | `/var/lib/ocis/storage/users/uploads` (from host `/var/lib/udrive-uploads`) | **1,500 – 3,200 MB/s**<br>(0ms network latency) | Buffers incoming in-flight upload chunks from browsers before assembly. |
| **Tier 2: Metadata & Config** | Longhorn RWX (`ReadWriteMany` NFSv4) | `/var/lib/ocis` (`udrive-data` 50Gi)<br>`/etc/ocis` (`udrive-config` 2Gi) | **100 – 250 MB/s**<br>(3x synchronous network replication) | Stores index metadata, user spaces, permissions, and system configuration. |
| **Tier 3: Permanent Blobs** | MinIO Distributed S3 | S3 bucket `udrive` at `https://10.1.18.7:9000` | High-throughput multi-part streaming (16 worker threads) | Permanent storage for assembled files and object blobs. |

### Why Scratch Storage Must Be on Local NVMe (Not Longhorn)
When a user uploads a 10GB file, ownCloud / TUS writes hundreds of temporary chunks to disk, re-reads them, and stitches them together before streaming to MinIO S3:
* **If Scratch is on Longhorn (NFS 3x Replicated)**:
  * Every write of a temporary chunk travels over the cluster network 3 times (to Node 1, Node 2, and Node 3).
  * Storage controller overhead causes latency spikes and locks, dropping throughput to ~40–90 MB/s.
  * Browser uploads time out, chunk writes fall behind, and user experience degrades.
* **With Scratch on Local NVMe SSD (`hostPath: /var/lib/udrive-uploads`)**:
  * Chunks write directly to the local node's PCIe NVMe controller at hardware line rate (>1,000 MB/s).
  * Zero cluster network bandwidth is wasted on temporary chunks.
  * Once the upload completes, UDrive's S3NG driver streams the assembled file directly into MinIO S3 using 16 concurrent threads (`STORAGE_USERS_S3NG_PUT_OBJECT_NUM_THREADS=16`).

---

## 🧩 OCIS Microservices Architecture

Inside the `udrive` container, ownCloud Infinite Scale operates as a coordinated set of lightweight microservices communicating via gRPC and NATS:

```
+------------------------------------------------------------------------------------+
|                               udrive Container                                     |
|                                                                                    |
|   +------------------+         +-------------------+         +-----------------+   |
|   |   Proxy (:9200)  | <-----> |   Frontend (DAV)  | <-----> |  Storage-Users  |   |
|   +--------+---------+         +---------+---------+         +--------+--------+   |
|            |                             |                            |            |
|            v                             v                            v            |
|     [ OpenID Connect ]             [ NATS Broker ]            [ S3NG Driver ]      |
|     (Keycloak / IDM)               (Events/Tasks)             (MinIO S3 Client)    |
|            |                             |                            |            |
|            v                             v                            v            |
|     +--------------+              +--------------+            +---------------+    |
|     |  IDM Service |              |  Thumbnails  |            | Local Scratch |    |
|     +--------------+              +--------------+            +---------------+    |
+------------------------------------------------------------------------------------+
```

### Key Microservices:
1. **`proxy`**: Serves as the internal API gateway, terminating TLS, authenticating requests via OpenID Connect (Keycloak/IDM), and routing traffic to downstream services.
2. **`frontend`**: Exposes the WebDAV, TUS, and OCS endpoints consumed by the web interface and sync clients.
3. **`storage-users`**: Manages user spaces and file hierarchies using the **S3NG (S3 NextGen)** driver.
4. **`thumbnails`**: Generates image, document, and video thumbnails asynchronously via NATS event bus.
5. **`idm`**: Embedded identity management service handling user accounts, groups, and permissions.
6. **`nats`**: Lightweight, high-performance messaging broker orchestrating asynchronous tasks across all pods.
7. **`valkey`**: In-memory Redis-compatible key-value cache accelerating session lookups and lock negotiations.

---

## 🔄 High Availability & Pod Scheduling

Replicas are scheduled across worker nodes using **Pod Anti-Affinity**:

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - udrive
          topologyKey: kubernetes.io/hostname
```

### Fault-Tolerance Matrix:
* **Node 1 reboot/failure**: Node 2 and Node 3 continue serving requests. Longhorn maintains quorum (2/3 replicas).
* **Network partition on 1 node**: Traefik automatically routes traffic to healthy pods on surviving nodes.
* **Auto-healing**: Kubernetes Deployment restarts failed containers; Longhorn rebuilds degraded replicas automatically once the node returns.
