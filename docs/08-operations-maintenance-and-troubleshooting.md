# 08 - Operations, Maintenance & Troubleshooting Runbook

This runbook provides Day-2 operational procedures, health check commands, disk space management, and troubleshooting workflows for maintaining UDrive in production.

---

## 🩺 Daily Health Checks

Execute these commands from your local terminal via SSH to `Node1`:

### 1. Check Pod Status
```bash
ssh Node1 "kubectl get pods -n udrive -o wide"
```
*Verify that all pods are `Running` and have `READY 2/2` or `1/1`.*

### 2. Check Pod Logs
```bash
# View live logs from the active udrive pods
ssh Node1 "kubectl logs -n udrive -l app.kubernetes.io/name=udrive --tail=100 -f"
```

### 3. Check Traefik Ingress & Stickiness
```bash
curl -I -s https://drive.unity-workspace.com | grep -i "set-cookie"
# Expected: Set-Cookie: udrive_sticky=...; Path=/; HttpOnly; Secure; SameSite=None
```

---

## 💾 Scratch Storage Maintenance (`/var/lib/udrive-uploads`)

The local NVMe scratch storage buffers in-flight chunks. TUS cleans up completed uploads automatically, but interrupted or abandoned uploads can leave orphaned chunks over time.

### Checking Free Scratch Disk Space:
```bash
ssh Node1 "df -h /var/lib/udrive-uploads"
ssh Node2 "df -h /var/lib/udrive-uploads"
ssh Node3 "df -h /var/lib/udrive-uploads"
```

### Cleaning Up Abandoned Upload Chunks (>7 Days Old):
If scratch storage exceeds 80% usage:
```bash
# Safely remove chunks older than 7 days
ssh Node1 "find /var/lib/udrive-uploads -type f -mtime +7 -delete"
ssh Node2 "find /var/lib/udrive-uploads -type f -mtime +7 -delete"
ssh Node3 "find /var/lib/udrive-uploads -type f -mtime +7 -delete"
```

---

## 🛠️ Troubleshooting Common Issues

### Issue 1: File Stuck in "Processing" (HTTP 425 Too Early)
* **Description**: A file shows a circular loop icon and cannot be previewed because background processing stalled.
* **Resolution**:
  1. In the Web UI (v1.4.15+), hover over the row and click the red **Trash (Delete)** button, or click the **Re-upload** button to replace it.
  2. In the 3-dots menu, click **Delete** or **Re-upload file**.
  3. If deleting via CLI is necessary:
     ```bash
     # Delete directly via WebDAV DELETE request with bearer token
     curl -X DELETE -H "Authorization: Bearer <TOKEN>" \
       "https://drive.unity-workspace.com/remote.php/dav/spaces/<SPACE_ID>/<PATH_TO_FILE>"
     ```

---

### Issue 2: Longhorn RWX Volume Mount Timeout
* **Description**: Pod fails to start with `Unable to attach or mount volumes: timed out waiting for the condition`.
* **Resolution**:
  1. Check Longhorn PVC and volume status:
     ```bash
     ssh Node1 "kubectl get pvc -n udrive"
     ssh Node1 "kubectl get volume.longhorn.io -n longhorn-system"
     ```
  2. If an NFS share manager pod is stuck, delete it to trigger recreation:
     ```bash
     ssh Node1 "kubectl delete pod -n longhorn-system -l longhorn.io/component=share-manager"
     ```

---

### Issue 3: Helm Deployment Rollback
If a deployment exhibits regressions in production:
1. List revision history:
   ```bash
   ssh Node1 "helm history udrive -n udrive"
   ```
2. Roll back to the previous stable revision (e.g., revision 52):
   ```bash
   ssh Node1 "helm rollback udrive 52 -n udrive"
   ```
3. Monitor the rollback:
   ```bash
   ssh Node1 "kubectl rollout status deployment/udrive -n udrive"
   ```

---

## 🔒 Secret Management

Administrative secrets (admin password, MinIO credentials, JWT secret keys) are managed in the `udrive` secret:

```bash
# Retrieve the admin password
ssh Node1 "kubectl get secret udrive -n udrive -o jsonpath='{.data.admin-password}' | base64 --decode; echo"
```
