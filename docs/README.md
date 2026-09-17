# 📚 UDrive Technical Documentation Suite

Welcome to the comprehensive technical documentation for **UDrive**. This suite covers system architecture, codebase design, development workflows, release runbooks, and operational maintenance.

---

## 🧭 Documentation Map

| Document | Description | Target Audience |
| :--- | :--- | :--- |
| [**01 - Architecture & System Design**](./01-architecture-and-system-design.md) | 3-node HA topology, 3-tier storage model (NVMe + Longhorn + MinIO), zero SPOF, and OCIS microservices. | Architects, Lead Engineers |
| [**02 - Codebase & Frontend Guide**](./02-codebase-and-frontend-guide.md) | `udrive-web` pnpm monorepo structure, App Switcher, Profile dropdown admin settings, and stuck processing files UX. | Frontend Developers |
| [**03 - Backend & Docker Engine**](./03-backend-and-docker-engine.md) | `udrive-server`, S3NG storage driver, multi-arch Docker build (`build-docker.sh`), and environment configurations. | Backend / DevOps Engineers |
| [**04 - Local Development & Setup**](./04-local-development-and-setup.md) | Step-by-step local setup, pnpm workspace installation, Vite HMR, and backend proxy configuration. | All Developers |
| [**05 - Build & Release Pipeline**](./05-build-and-release-pipeline.md) | Production release runbook: frontend build -> multi-arch Docker image -> Helm chart packaging -> Kubernetes rollout. | Release Engineers, Tech Leads |
| [**06 - Upload Pipeline & Cloudflare**](./06-upload-pipeline-and-cloudflare.md) | Cloudflare 100MB body limit, 50MB deterministic chunking, and Traefik sticky sessions (`udrive_sticky`). | DevOps, Systems Engineers |
| [**07 - Media Streaming & Previews**](./07-media-streaming-preview-and-office.md) | Video formats (`.mov` vs `.mp4`, `+faststart`), Collabora Online Office integration, and client error diagnostics. | Full-Stack Developers |
| [**08 - Operations & Troubleshooting**](./08-operations-maintenance-and-troubleshooting.md) | Day-2 health checks, NVMe scratch cleanup, recovering stuck files, Longhorn recovery, and Helm rollback. | Site Reliability Engineers (SRE) |
