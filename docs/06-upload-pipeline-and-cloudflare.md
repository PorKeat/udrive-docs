# 06 - Upload Pipeline & Cloudflare Optimization

This document explains the mechanics of large file uploads (>100MB up to 50GB+) in UDrive, how Cloudflare HTTP 413 errors were eliminated, and how Traefik sticky sessions guarantee zero 404 chunk failures.

---

## ⚠️ The Cloudflare HTTP 413 Problem

Cloudflare proxies all public traffic to `drive.unity-workspace.com`. On standard Cloudflare plans (Free, Pro, Business), Cloudflare enforces a hard ceiling:

> **Maximum HTTP Client Request Body Size: 100 MB**

If any single HTTP request payload exceeds 100 MB, Cloudflare's edge servers immediately drop the connection:
```http
HTTP/2 413 Request Entity Too Large
Server: cloudflare
```
The request never reaches your Kubernetes ingress or UDrive pods.

### Why Default OCIS Setups Fail:
By default, ownCloud Web sends chunks between 95MB and 200MB. Because HTTP headers, multipart delimiters, and TLS framing add overhead, a 95MB payload easily crosses 100MB on wire, triggering an instant Cloudflare `413` abort.

---

## 🛠️ The Solution: 50MB Deterministic Chunking

To make large uploads 100% reliable through Cloudflare edge nodes:

1. The frontend chunk size is strictly configured to **50 MB** (`52428800` bytes):
   ```yaml
   - name: FRONTEND_UPLOAD_MAX_CHUNK_SIZE
     value: "52428800"
   ```
2. When a user uploads a 10GB file:
   * The browser's JavaScript TUS client slices the file into exactly **200 pieces of 50 MB each**.
   * Every single 50MB request travels through Cloudflare safely below the 100MB ceiling.
   * Cloudflare forwards every chunk with `HTTP 200 / 204 OK`.

```
[ 10 GB Video File ]
       |
       +--> [ Chunk 1:  50 MB ] ---> Cloudflare (Pass) ---> UDrive Node
       +--> [ Chunk 2:  50 MB ] ---> Cloudflare (Pass) ---> UDrive Node
       +--> [ Chunk 3:  50 MB ] ---> Cloudflare (Pass) ---> UDrive Node
       +--> ...
       +--> [ Chunk 200: 50 MB] ---> Cloudflare (Pass) ---> UDrive Node
```

---

## 🎯 Sticky Sessions via Traefik Ingress

In a multi-replica cluster, if Chunk 1 lands on **Pod A (Node 1)** and Chunk 2 lands on **Pod B (Node 3)**:
* Pod B does not have Chunk 1 in its local scratch directory.
* Pod B returns `404 Not Found` or `409 Conflict`, causing the entire upload to fail.

### Traefik Cookie Stickiness Configuration
Sticky session annotations are applied directly to the `udrive` Kubernetes Service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: udrive
  namespace: udrive
  annotations:
    traefik.ingress.kubernetes.io/service.sticky.cookie: "true"
    traefik.ingress.kubernetes.io/service.sticky.cookie.name: "udrive_sticky"
    traefik.ingress.kubernetes.io/service.sticky.cookie.secure: "true"
    traefik.ingress.kubernetes.io/service.sticky.cookie.httponly: "true"
    traefik.ingress.kubernetes.io/service.sticky.cookie.samesite: "none"
```

### How It Works:
1. When the client initiates the session, Traefik generates an opaque sticky cookie:
   ```http
   Set-Cookie: udrive_sticky=4adbcb387fa56242; Path=/; HttpOnly; Secure; SameSite=None
   ```
2. During upload of all chunks, the browser sends this cookie with every PATCH request.
3. Traefik routes all chunks to the **exact same pod replica**.
4. The pod writes chunks to its local NVMe scratch folder (`/var/lib/ocis/storage/users/uploads`) at hardware line rate.
5. Once all chunks are assembled, the pod streams the complete file into MinIO S3 via 16 parallel threads.

---

## 🌊 Complete End-to-End Upload Flow

```
[ Web Browser ]
      |
      | 1. POST /remote.php/dav/spaces/... (Initiate TUS upload)
      v
[ Cloudflare Edge ]
      | 2. Passes request (Header only, <1KB)
      v
[ Traefik Ingress ]
      | 3. Reads cookie 'udrive_sticky' -> routes to Pod on Node 3
      v
[ UDrive Pod (Node 3) ]
      | 4. Reserves upload ID in local NVMe (/var/lib/udrive-uploads)
      | 5. Client streams Chunk 1 (50MB) -> written at >1,000 MB/s
      | 6. Client streams Chunk 2 (50MB) -> written at >1,000 MB/s
      | 7. Final chunk received -> assembly completed locally
      | 8. S3NG driver streams object to MinIO S3 (16 threads)
      v
[ MinIO S3 Distributed Bucket ]
      | 9. Object stored permanently; metadata indexed in Longhorn DB
      v
[ Response HTTP 201 Created ]
```
