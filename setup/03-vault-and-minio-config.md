# 03 - HashiCorp Vault & MinIO S3 Configuration

UDrive integrates with **HashiCorp Vault** for dynamic secret injection and **MinIO S3** for permanent object storage.

---

## 🔒 1. HashiCorp Vault Setup

* **Vault Server URL**: `https://10.1.18.8:8200`
* **Kubernetes Auth Path**: `auth/kubernetes`
* **Vault Role**: `udrive-role`
* **Target Secret Path**: `secret/data/udrive` (KV v2)

### A. Define the Vault Policy:
```hcl
path "secret/data/udrive" {
  capabilities = ["read"]
}
```

### B. Map Policy to Kubernetes ServiceAccount:
```bash
vault write auth/kubernetes/role/udrive-role \
    bound_service_account_names=udrive \
    bound_service_account_namespaces=udrive \
    policies=udrive-policy \
    ttl=24h
```

### C. Populate Secrets in Vault:
Write the required keys into `secret/data/udrive`:
```bash
vault kv put secret/udrive \
    admin_password="<SECURE_ADMIN_PASSWORD>" \
    s3_access_key="<MINIO_ACCESS_KEY>" \
    s3_secret_key="<MINIO_SECRET_KEY>" \
    s3_ca_cert="<MINIO_ROOT_CA_CERTIFICATE_PEM>"
```

### D. Sidecar Secret Ingestion Template:
In `templates/deployment.yaml`, the Vault Agent injects the environment variables automatically via annotations:
```yaml
vault.hashicorp.com/agent-inject-secret-udrive: "secret/data/udrive"
vault.hashicorp.com/agent-inject-template-udrive: |
  {{- with secret "secret/data/udrive" -}}
  export IDM_ADMIN_PASSWORD="{{ .Data.data.admin_password }}"
  export STORAGE_USERS_S3NG_ACCESS_KEY="{{ .Data.data.s3_access_key }}"
  export STORAGE_USERS_S3NG_SECRET_KEY="{{ .Data.data.s3_secret_key }}"
  {{- end -}}
```

---

## 🪣 2. MinIO S3 Object Storage Setup

* **MinIO Endpoint**: `https://10.1.18.7:9000`
* **Bucket Name**: `udrive`
* **Region**: `default`

### A. Create the S3 Bucket:
Ensure the bucket `udrive` is created in MinIO using the MinIO Client (`mc`) or Web Console:
```bash
mc alias set myminio https://10.1.18.7:9000 <ACCESS_KEY> <SECRET_KEY> --insecure
mc mb myminio/udrive --insecure
```

### B. Bucket Versioning & Locking:
- Versioning can be enabled if revision history is desired at the object level.
- Object locking should be disabled for normal OCIS operation.
