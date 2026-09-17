# 01 - Node Prerequisites & Local NVMe Setup

Before deploying UDrive, every worker node that will host UDrive pods **must** have the local NVMe scratch upload directory created with correct permissions.

---

## 🖥️ Target Cluster Nodes

* **`node1`**: `10.1.16.11` (Control plane & worker)
* **`node2`**: `10.1.16.12` (Worker)
* **`node3`**: `10.1.16.13` (Worker)

---

## 📁 Step 1: Initialize Scratch Storage via Host Shell

If you have SSH access to each node:

```bash
# 1. Create the directory
sudo mkdir -p /var/lib/udrive-uploads

# 2. Set ownership to UID 1000 (ocis-user) and GID 1000 (ocis-group)
sudo chown -R 1000:1000 /var/lib/udrive-uploads

# 3. Grant full read, write, and traverse permissions to user and group
sudo chmod 775 /var/lib/udrive-uploads

# 4. Verify directory permissions
ls -ld /var/lib/udrive-uploads
# Expected output:
# drwxrwxr-x 2 1000 1000 4096 /var/lib/udrive-uploads
```

---

## 🚀 Step 2: Automated Initialization via Kubernetes (Alternative)

If direct SSH to worker nodes is restricted, deploy the provided initialization DaemonSet:

```bash
sudo kubectl apply -f manifest/raw-manifests/init-node-scratch.yaml
```

Once all pods report `Running`, verify that the folder exists on all nodes:
```bash
sudo kubectl get daemonset init-udrive-scratch -n kube-system
```

Then delete the DaemonSet:
```bash
sudo kubectl delete daemonset init-udrive-scratch -n kube-system
```
