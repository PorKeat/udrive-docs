# 02 - Offline Container Image Caching

In environments where worker nodes (`node2`, `node3`) do not have direct internet egress, pulling images from `ghcr.io` or `docker.io` will result in `ImagePullBackOff` or `ErrImagePull` due to TLS connection timeouts.

This guide details how to export images on the gateway/control plane node (`node1`) and import them into containerd on worker nodes.

---

## 📦 Required Container Images

1. `ghcr.io/unity-workspace-org/udrive:v1.1.8` (Main UDrive container)
2. `docker.io/hashicorp/vault:1.15.2` (Vault Agent sidecar container)

---

## 🛠️ Step-by-Step Caching Runbook

### Step 1: Export Complete Multi-Platform Archive on Node 1

On `node1` (which has internet egress):

```bash
# Pull all platform layers to guarantee complete digests
sudo ctr --namespace k8s.io images pull --all-platforms ghcr.io/unity-workspace-org/udrive:v1.1.8
sudo ctr --namespace k8s.io images pull --all-platforms docker.io/hashicorp/vault:1.15.2

# Export multi-platform tar archives
sudo ctr --namespace k8s.io images export --all-platforms /tmp/udrive-v1.1.8.tar ghcr.io/unity-workspace-org/udrive:v1.1.8
sudo ctr --namespace k8s.io images export --all-platforms /tmp/vault-1.15.2.tar docker.io/hashicorp/vault:1.15.2
```

---

### Step 2: Copy Tarballs to Longhorn RWX Shared Storage

Use `kubectl cp` to transfer the tarballs into the existing Longhorn RWX persistent volume via any running pod:

```bash
POD_NAME=$(sudo kubectl get pods -n udrive -l app.kubernetes.io/name=udrive -o jsonpath='{.items[0].metadata.name}')

sudo kubectl cp /tmp/udrive-v1.1.8.tar udrive/${POD_NAME}:/var/lib/ocis/udrive-v1.1.8.tar -c udrive
sudo kubectl cp /tmp/vault-1.15.2.tar udrive/${POD_NAME}:/var/lib/ocis/vault-1.15.2.tar -c udrive

# Remove temporary files on Node 1
sudo rm -f /tmp/udrive-v1.1.8.tar /tmp/vault-1.15.2.tar
```

---

### Step 3: Import Images into containerd on Target Worker Node

Deploy the importer pod targeting the destination node (e.g., `node3`):

```bash
sudo kubectl run import-images-node3 -n udrive --image=docker.io/longhornio/longhorn-manager:v1.12.1 \
  --image-pull-policy=IfNotPresent --restart=Never --overrides='
{
  "spec": {
    "nodeSelector": {"kubernetes.io/hostname": "node3"},
    "volumes": [
      {"name": "host-root", "hostPath": {"path": "/"}},
      {"name": "udrive-data", "persistentVolumeClaim": {"claimName": "udrive-data"}}
    ],
    "containers": [{
      "name": "importer",
      "image": "docker.io/longhornio/longhorn-manager:v1.12.1",
      "command": [
        "/bin/sh", "-c",
        "cp /shared/udrive-v1.1.8.tar /host/tmp/ && cp /shared/vault-1.15.2.tar /host/tmp/ && chroot /host /usr/local/bin/ctr --namespace k8s.io images import /tmp/udrive-v1.1.8.tar && chroot /host /usr/local/bin/ctr --namespace k8s.io images import /tmp/vault-1.15.2.tar && rm -f /host/tmp/*.tar /shared/*.tar"
      ],
      "volumeMounts": [
        {"name": "host-root", "mountPath": "/host"},
        {"name": "udrive-data", "mountPath": "/shared"}
      ],
      "securityContext": {"privileged": true}
    }]
  }
}'
```

Watch logs until completion:
```bash
sudo kubectl logs -f import-images-node3 -n udrive
```

Clean up the importer pod:
```bash
sudo kubectl delete pod import-images-node3 -n udrive
```

---

### Step 4: Verification

Verify that the target node now has the images locally cached:
```bash
# In values.yaml, ensure pullPolicy remains IfNotPresent:
# image:
#   pullPolicy: IfNotPresent
```
When pods schedule on this node, containerd will immediately use the local cache without making external network calls.
