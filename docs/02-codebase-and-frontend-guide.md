# 02 - Codebase & Frontend Developer Guide

This document provides a comprehensive guide to the **`udrive-web`** frontend codebase: architecture, pnpm monorepo packages, core UI components, and all custom features engineered for the Unity Workspace ecosystem.

---

## 📂 Frontend Monorepo Structure (`udrive-web`)

`udrive-web` is built on **Vue 3**, **Vite**, **TypeScript**, and **Pinia**, managed as a `pnpm` monorepo:

```text
udrive-web/
├── packages/
│   ├── design-system/       # Reusable UI component library (buttons, icons, modals, tables)
│   ├── web-client/          # TypeScript WebDAV client, models (Resource, SpaceResource), parsers
│   ├── web-pkg/             # Core application framework, composables, pinia stores, routing
│   ├── web-runtime/         # Host shell, TopBar, sidebar navigation, App Switcher, instances modal
│   ├── web-app-files/       # Main file manager app (ResourceTable, QuickActions, ContextActions)
│   └── web-app-preview/     # Universal file preview engine (PDF, text, images, video, audio)
├── pnpm-workspace.yaml      # Monorepo configuration
├── package.json             # Root scripts and dev dependencies
└── vite.config.ts           # Build and development configuration
```

### Core Package Roles:
* **`@ownclouders/design-system`**: Design system primitives (`OcButton`, `OcIcon`, `OcTable`, `OcModal`, `OcCheckbox`).
* **`@ownclouders/web-client`**: High-performance WebDAV and OCS client library. Handles XML multistatus parsing (`parsers.ts`) and creates `Resource` model instances (`buildResource`).
* **`@ownclouders/web-pkg`**: State management (Pinia stores for resources, spaces, user credentials), action definitions (`useFileActionsDelete`, `useFileActionsCopy`), and table components (`ResourceTable.vue`, `ResourceTile.vue`).
* **`@ownclouders/web-runtime`**: Global top navigation header (`TopBar.vue`), user profile menu, and cross-application app switcher.
* **`@ownclouders/web-app-files`**: File browsing views, breadcrumbs, search, sidebars, and row-level quick actions (`QuickActions.vue`).

---

## 🎨 Key Features & Customizations

### 1. Unity Workspace App Switcher
Located in the upper navigation bar (`packages/web-runtime/src/components/Topbar/TopBar.vue`), the 9-dots App Switcher icon allows users to seamlessly jump between Unity Workspace products:
* **Drive** (`https://drive.unity-workspace.com`)
* **Office** (`https://office.unity-workspace.com`)
* **Calendar** (`https://calendar.unity-workspace.com`)
* **Meet** (`https://meet.unity-workspace.com`)
* **Mail** (`https://mail.unity-workspace.com`)

The switcher uses native SVG brand icons and preserves active authentication tokens across domains.

---

### 2. Clean Topbar: Admin Settings in Profile Dropdown
To keep the top navigation header uncluttered, the **Admin Settings** link was relocated from the top navbar into the **User Profile Dropdown** menu:
* **Location**: `packages/web-runtime/src/components/Topbar/UserMenu.vue` & `TopBar.vue`
* **Access Control**: Only visible when the authenticated user has the `admin` role.
* Clicking "Admin Settings" smoothly routes to `/admin-settings` without losing the file list context.

---

### 3. Stuck Processing Files Handling & UX (v1.4.15)

#### The Problem:
When large files are uploaded, ownCloud background workers process them asynchronously. If a worker gets interrupted, the file remains stuck in the processing state (`HTTP 425 Too Early`). In standard OCIS, stuck files cannot be deleted, opened, or re-uploaded, and their three-dot menu contains irrelevant actions.

#### The Solution:
1. **Disabled & Dimmed Visual State**:
   * In `packages/web-pkg/src/components/FilesList/ResourceTable.vue` and `ResourceTile.vue`, rows with `processing === true` receive the classes `.oc-row-processing-disabled` and `.oc-tile-card-processing`.
   * Row opacity is reduced to `0.65`, hover highlights are subdued, and the mouse cursor changes to `not-allowed`.
2. **Direct Row Quick-Action Buttons**:
   * In `packages/web-app-files/src/components/FilesList/QuickActions.vue`:
     * When `item.processing` is true, standard buttons (favorite, share) are replaced by a **Trash / Delete button** (`delete-bin-5` in danger/red color) and a **Re-upload button** (`upload-cloud-2`).
     * Clicking Trash triggers immediate deletion via `useFileActionsDelete`.
     * Clicking Re-upload immediately invokes the hidden file input element (`#files-file-upload-input`) to re-upload.
3. **Restricted Context Menu**:
   * In `packages/web-pkg/src/components/FilesList/ContextActions.vue`:
     * If a processing item is selected, all standard actions (Share, Copy Link, Edit, Duplicate, Favorite, Details) are stripped out.
     * The popup menu shows strictly **Delete** and **Re-upload file**.
4. **Enabling Deletion Permissions**:
   * In `packages/web-client/src/helpers/resource/functions.ts`:
     * `canBeDeleted()` was updated to return `true` if `this.processing` is true, bypassing the missing `'D'` permission header from 425 responses:
     ```typescript
     canBeDeleted: function () {
       return this.processing || this.permissions.indexOf(DavPermission.Deletable) >= 0
     }
     ```
   * Single-item lock checks in `useFileActionsDelete.ts` were updated to allow deletion if `resource.processing` is true.

---

### 4. Collabora Online Office Integration
UDrive integrates with **Collabora Online** (`office.unity-workspace.com`) to allow real-time editing of Office documents (`.docx`, `.xlsx`, `.pptx`, `.odt`, `.ods`, `.odp`):
* Documents open in an embedded full-screen iframe inside `packages/web-app-preview/src/views/Preview.vue`.
* Secure WOPI (Web Application Open Platform Interface) tokens are generated on-the-fly and refreshed automatically.
* Preview loading flicker was eliminated by ensuring the iframe loading state remains stable until Collabora emits `App_LoadingStatus: Document_Loaded`.

---

## 🛠️ Styling & Theming Guidelines

* Custom styles reside in scoped SCSS blocks or global theme overrides.
* Use CSS variables for consistent colors:
  * Primary brand: `var(--oc-color-primary, #1e40af)`
  * Danger / Destructive: `var(--oc-color-background-danger, #fee2e2)` / `#ef4444`
  * Text muted: `var(--oc-color-text-muted, #64748b)`
  * Background secondary: `var(--oc-color-background-secondary, #f8fafc)`
