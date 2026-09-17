# 05 - Build & Release Pipeline Runbook

This document provides the exact, production-verified step-by-step release process for deploying updates to **UDrive**. Any engineer can follow this runbook to deliver frontend or backend changes to production safely and reliably.

---

## 🔁 Overview of the Release Workflow

A standard release flows across three repositories:

```
[ udrive-web ]              [ udrive-server ]            [ udrive-helm-chart ]            [ Kubernetes Node1 ]
      |                            |                              |                                |
  1. Build Web Assets              |                              |                                |
  2. Commit & Tag (v1.4.x)         |                              |                                |
      \                            |                              |                                |
       +---------------------> 3. Build Multi-Arch                |                                |
                                  Docker Image                    |                                |
                                  (amd64 + arm64)                 |                                |
                                   \                              |                                |
                                    +-----------------------> 4. Bump Chart Version                |
                                                              5. Package .tgz                      |
                                                              6. Commit & Tag                      |
                                                                  \                                |
                                                                   +-------------------------> 7. scp package
                                                                                               8. helm upgrade
                                                                                               9. Verify rollout
```

---

## 📋 Step-by-Step Release Instructions

### Step 1: Build & Release `udrive-web`

1. Navigate to the web repository and ensure you are on the working branch:
   ```bash
   cd /Users/alexkgm/Desktop/udrive-project/udrive-web
   git checkout porkeat
   git status
   ```

2. Compile the production bundle:
   ```bash
   pnpm run build
   ```
   *Verify that Vite completes without errors (`built in ~25s`).*

3. Commit your changes and tag the release:
   ```bash
   git add .
   git commit -m "feat(files): your change description"
   git tag v1.4.16   # Replace with next version number
   git push origin porkeat
   git push origin v1.4.16
   ```

---

### Step 2: Build & Push Multi-Arch Docker Image (`udrive-server`)

1. Navigate to the server repository:
   ```bash
   cd /Users/alexkgm/Desktop/udrive-project/udrive-server
   ```

2. Run the multi-arch build script targeting GitHub Container Registry (`ghcr.io`):
   ```bash
   ./build-docker.sh --multiarch ghcr.io/unity-workspace-org/udrive:v1.4.16 --skip-compile
   ```
   *This script uses `docker buildx` to compile, tag, and push manifests for both `linux/amd64` and `linux/arm64`.*
   *Wait until the script outputs `Successfully built and pushed multi-arch image`.*

---

### Step 3: Package Helm Chart (`udrive-helm-chart`)

1. Navigate to the Helm chart repository:
   ```bash
   cd /Users/alexkgm/Desktop/udrive-project/udrive-helm-chart
   ```

2. Bump the chart version and image tag:
   * In `Chart.yaml`:
     ```yaml
     version: 0.3.27        # Increment patch version
     appVersion: "1.4.16"   # Matches udrive version
     ```
   * In `values.yaml`:
     ```yaml
     image:
       tag: "v1.4.16"
     ```

3. Package the chart into a `.tgz` archive:
   ```bash
   helm package .
   # Output: Successfully packaged chart and saved it to: .../udrive-0.3.27.tgz
   ```

4. Commit, tag, and push the chart:
   ```bash
   git add Chart.yaml values.yaml
   git commit -m "release: bump chart version to 0.3.27 (udrive v1.4.16)"
   git tag v0.3.27
   git push origin porkeat
   git push origin v0.3.27
   ```

---

### Step 4: Deploy to Kubernetes Cluster

1. Copy the packaged Helm archive to the primary cluster master node (`Node1`):
   ```bash
   scp udrive-0.3.27.tgz Node1:/tmp/udrive-0.3.27.tgz
   ```

2. Execute the Helm upgrade remotely via SSH:
   ```bash
   ssh Node1 "helm upgrade udrive /tmp/udrive-0.3.27.tgz --namespace udrive --reuse-values --set image.tag=v1.4.16"
   ```

3. Monitor the rolling update rollout:
   ```bash
   ssh Node1 "kubectl rollout status deployment/udrive -n udrive"
   ```
   *Expected output: `deployment "udrive" successfully rolled out`.*

---

### Step 5: Post-Deployment Verification

1. Check that all pods are healthy and in `Running` state:
   ```bash
   ssh Node1 "kubectl get pods -n udrive"
   ```

2. Verify HTTP response and SSL termination via curl:
   ```bash
   curl -I -s -k https://drive.unity-workspace.com
   # Expected status: HTTP/2 200
   ```

3. Open [https://drive.unity-workspace.com](https://drive.unity-workspace.com) in your browser:
   * Perform a test upload of a small and large file.
   * Verify thumbnail generation and file preview.
   * Check browser DevTools console for clean execution without unhandled errors.
