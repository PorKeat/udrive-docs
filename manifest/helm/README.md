# UDrive Helm Chart

Production-ready Kubernetes Helm chart for **UDrive** (ownCloud Infinite Scale) Cloud Storage and Collaboration Platform.

## Overview

UDrive provides enterprise file sync, share, and collaboration capabilities. This Helm chart packages UDrive as a unified, high-performance containerized service suitable for modern Kubernetes clusters.

### Features
- **All-in-One Deployment**: Simplified single-pod architecture with ~500MiB idle memory footprint.
- **Storage Flexibility**: Supports local Kubernetes Persistent Volume Claims (`driver: ocis`) or S3-compatible Object Storage (`driver: s3ng`, e.g. MinIO, AWS S3, Ceph).
- **Authentication**: Built-in IdP/LDAP directory or integration with external OIDC providers like Keycloak.
- **Document Editing**: Ready for WOPI/Collabora Online integration.
- **Security**: Runs as non-root (UID 1000) with least-privilege securityContext.

---

## Prerequisites

- Kubernetes 1.22+
- Helm 3.8.0+
- Ingress Controller (e.g. `ingress-nginx`)
- Persistent Volume provisioner in your cluster (if using PVC storage)

---

## Quick Start

### 1. Install Chart with Defaults

```bash
helm install udrive ./udrive-chart \
  --namespace udrive \
  --create-namespace \
  --set udrive.url="https://drive.yourdomain.com" \
  --set ingress.hosts[0].host="drive.yourdomain.com" \
  --set ingress.tls[0].hosts[0]="drive.yourdomain.com"
```

### 2. Retrieve Initial Admin Password

```bash
kubectl get secret -n udrive udrive -o jsonpath="{.data.admin-password}" | base64 --decode; echo
```

### 3. Check Pod Status

```bash
kubectl rollout status deployment/udrive -n udrive
kubectl get pods -n udrive
```

---

## Common Configurations

### Scenario A: Using MinIO / S3 Object Storage

Save this to `values-s3.yaml`:

```yaml
udrive:
  url: "https://drive.yourdomain.com"
  admin:
    password: "YourSecureAdminPassword123!"

storage:
  driver: s3ng
  s3:
    endpoint: "http://minio.storage.svc.cluster.local:9000"
    region: "us-east-1"
    bucket: "udrive-data"
    insecure: true
    accessKey: "minioadmin"
    secretKey: "miniopassword"

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/proxy-body-size: "20G"
  hosts:
    - host: drive.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: udrive-tls
      hosts:
        - drive.yourdomain.com
```

Deploy with:
```bash
helm upgrade --install udrive ./udrive-chart -n udrive -f values-s3.yaml
```

---

### Scenario B: Keycloak OIDC Authentication

Save this to `values-keycloak.yaml`:

```yaml
auth:
  provider: oidc
  oidc:
    enabled: true
    issuer: "https://auth.yourdomain.com/realms/unity-workspace"
    clientId: "udrive"
    authority: "https://auth.yourdomain.com/realms/unity-workspace"
    scope: "openid profile email"
    autoProvisionAccounts: true
    userClaim: "preferred_username"
```

Deploy with:
```bash
helm upgrade --install udrive ./udrive-chart -n udrive -f values-keycloak.yaml
```

---

## Configuration Reference

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | UDrive container image repository | `ghcr.io/unity-workspace-org/udrive` |
| `image.tag` | Image tag | `v1.1.2` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `udrive.url` | External URL for accessing UDrive | `https://drive.example.com` |
| `udrive.logLevel` | Log level (`info`, `debug`, `warn`, `error`) | `info` |
| `udrive.insecure` | Allow unverified certificates internally | `false` |
| `udrive.admin.username` | Admin account username | `admin` |
| `udrive.admin.password` | Initial admin password (empty = random 16 chars) | `admin` |
| `udrive.admin.existingSecret` | Existing Kubernetes secret containing admin password | `""` |
| `udrive.demoUsers` | Create demo users (`einstein`, `marie`, `katherine`) | `false` |
| `udrive.enableBasicAuth` | Enable HTTP Basic Auth (for WebDAV clients) | `true` |
| `auth.provider` | Auth provider (`internal` or `oidc`) | `internal` |
| `auth.oidc.enabled` | Enable external OIDC authentication | `false` |
| `auth.oidc.issuer` | OIDC Issuer URL | `""` |
| `auth.oidc.clientId` | OIDC Client ID | `udrive` |
| `storage.driver` | Storage driver (`ocis` for PVC, `s3ng` for S3) | `ocis` |
| `storage.s3.endpoint` | S3 API endpoint | `http://minio:9000` |
| `storage.s3.bucket` | S3 bucket name | `udrive` |
| `storage.s3.accessKey` | S3 access key | `""` |
| `storage.s3.secretKey` | S3 secret key | `""` |
| `persistence.data.enabled` | Enable PVC for `/var/lib/ocis` | `true` |
| `persistence.data.size` | PVC size for data | `50Gi` |
| `persistence.config.enabled` | Enable PVC for `/etc/ocis` | `true` |
| `persistence.config.size` | PVC size for config/keys | `2Gi` |
| `resources.limits.memory` | Memory limit | `2048Mi` |
| `resources.requests.memory` | Memory request | `512Mi` |
| `autoscaling.enabled` | Enable Horizontal Pod Autoscaler (HPA) | `false` |
| `autoscaling.minReplicas` | Minimum pod replicas | `1` |
| `autoscaling.maxReplicas` | Maximum pod replicas | `5` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU % for scaling | `80` |
| `redis.enabled` | Enable shared Redis (for HPA / multi-pod locks) | `false` |
| `redis.endpoint` | Redis host:port endpoint | `""` |
| `ingress.enabled` | Enable Ingress controller routing | `true` |
| `ingress.className` | Ingress class name | `nginx` |

---

## Uninstalling the Chart

```bash
helm uninstall udrive -n udrive
```

> **Note:** Persistent Volume Claims (`PVCs`) are not automatically deleted by Helm to prevent accidental data loss. To delete them manually:
> ```bash
> kubectl delete pvc -l app.kubernetes.io/name=udrive -n udrive
> ```
