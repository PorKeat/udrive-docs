# 04 - Helm Installation & Upgrade Guide

This guide covers deploying, validating, and managing the UDrive Helm release on Kubernetes.

---

## 📍 Chart Location

* **On the Cluster**: `/home/vuthy/udrive-helm-chart/`
* **Local Copy**: `manifest/helm/`

All commands should be executed from `node1` (`10.1.16.11`).

---

## 🚀 Step 1: Pre-Deployment Validation

Always render and validate the chart templates before executing a live upgrade:

```bash
sudo helm template udrive /home/vuthy/udrive-helm-chart -n udrive > /dev/null && echo "✅ Helm templates are valid."
```

If there are any syntax errors, YAML indentation problems, or missing variables, the command will display the exact line and error.

---

## 📦 Step 2: Deploy / Upgrade Release

Deploy or upgrade the release in the `udrive` namespace:

```bash
sudo helm upgrade --install udrive /home/vuthy/udrive-helm-chart -n udrive
```

---

## 🔍 Step 3: Monitor Rollout Progress

Watch the rolling update progress until all replicas reach readiness:

```bash
# Check UDrive main service rollout
sudo kubectl rollout status deploy/udrive -n udrive

# Check IDM (LDAP) service rollout
sudo kubectl rollout status deploy/udrive-idm -n udrive
```

---

## 🩺 Step 4: Verify Multi-Node Distribution

Check that the pods are balanced across all available nodes:

```bash
sudo kubectl get pods -n udrive -o wide
```

Expected healthy output shows replicas running across `node1`, `node2`, and `node3`:
```text
NAME                           READY   STATUS    NODE    IP
udrive-6d78d5668c-phcwk        2/2     Running   node1   10.233.66.129
udrive-6d78d5668c-gz2g2        2/2     Running   node2   10.233.64.224
udrive-6d78d5668c-k9lkq        2/2     Running   node2   10.233.64.105
udrive-6d78d5668c-9rnv4        2/2     Running   node3   10.233.65.160
udrive-6d78d5668c-pkswd        2/2     Running   node3   10.233.65.169
udrive-idm-86d96495dd-nrgjz    2/2     Running   node1   10.233.66.66
udrive-nats-6c89556d8d-vtfgp   1/1     Running   node1   10.233.66.157
udrive-valkey-8d9446cc-lk85s   1/1     Running   node1   10.233.66.220
```

---

## 🌐 Step 5: Test End-to-End Connectivity

Verify that the external URL returns `200 OK` and injects the sticky session cookie:

```bash
curl -k -I https://drive.unity-workspace.com
```

Look for:
```http
HTTP/2 200
set-cookie: udrive_sticky=...; Path=/; HttpOnly; Secure; SameSite=None
server: cloudflare
```

---

## ⏪ Rollback Procedure (Emergency Recovery)

If an issue occurs after an upgrade:

```bash
# 1. Check release history
sudo helm history udrive -n udrive

# 2. Rollback to the previous stable revision (e.g. revision 16)
sudo helm rollback udrive 16 -n udrive

# 3. Monitor rollout of previous revision
sudo kubectl rollout status deploy/udrive -n udrive
```
