# 04 - Local Development & Setup Guide

This guide walks through setting up your local development environment for **`udrive-web`** and connecting it to a staging or production backend.

---

## 💻 Prerequisites

Ensure your development machine has the following tools installed:

| Tool | Minimum Version | Installation / Verification |
| :--- | :--- | :--- |
| **Node.js** | `>= 20.x` | `node -v` |
| **pnpm** | `>= 9.x` | `pnpm -v` (`corepack enable pnpm` or `npm i -g pnpm`) |
| **Git** | `>= 2.40` | `git --version` |
| **Docker** | `>= 26.x` | `docker --version` |
| **GitHub CLI** | `>= 2.50` | `gh --version` |
| **Helm** | `>= 3.14` | `helm version` |
| **kubectl** | `>= 1.28` | `kubectl version --client` |

---

## 🚀 Setting Up `udrive-web`

### 1. Clone the Repository
```bash
git clone https://github.com/unity-workspace-org/udrive-web.git
cd udrive-web
git checkout porkeat
```

### 2. Install Dependencies
UDrive Web uses `pnpm` workspace filters:
```bash
pnpm install
```

### 3. Running the Local Dev Server
To launch the Vite development server with Hot Module Replacement (HMR):
```bash
pnpm run dev
```
By default, the server starts at `http://localhost:8080`.

### 4. Connecting Local Frontend to Remote Backend
By default, the frontend will proxy API and WebDAV calls to the configured backend.
Create or inspect `.env.local` or edit `vite.config.ts`:
```typescript
server: {
  port: 8080,
  proxy: {
    '/remote.php': {
      target: 'https://drive.unity-workspace.com',
      changeOrigin: true,
      secure: false
    },
    '/ocs': {
      target: 'https://drive.unity-workspace.com',
      changeOrigin: true,
      secure: false
    },
    '/api': {
      target: 'https://drive.unity-workspace.com',
      changeOrigin: true,
      secure: false
    }
  }
}
```

---

## 🧪 Building & Verification

### Running Linter & Type Checks
```bash
# Check code formatting and TypeScript types
pnpm run lint
```

### Compiling Production Build
```bash
pnpm run build
```
* The compiled production distribution is written to `services/web/assets/core` or `dist/`.
* When the build finishes, verify that chunks are generated without errors.

---

## 💡 Developer Tips & Best Practices

1. **Working with Composables**:
   * All file operations (delete, copy, move, favorite) are organized in `packages/web-pkg/src/composables/actions/`.
   * When modifying action behaviors, update both `isVisible()` and `handler()`.
2. **WebDAV Properties**:
   * Inspect raw WebDAV XML responses in the browser DevTools **Network** tab (look for `PROPFIND` requests).
   * Note that processing files return `HTTP/1.1 425 TOO EARLY` in the `<d:status>` element.
3. **Icons & Design System**:
   * We use Remix Icon and Lucide icons via `packages/design-system/src/components/OcIcon/`.
   * Check `lucideMapping.ts` for icon name translations.
