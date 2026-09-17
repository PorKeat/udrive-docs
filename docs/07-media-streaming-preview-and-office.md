# 07 - Media Streaming, Previews & Office Integration

This document details the mechanics of media previews, Collabora Online Office document integration, browser video streaming performance, and client error diagnostics.

---

## 📄 Collabora Online Office Document Integration

UDrive integrates natively with **Collabora Online** (`office.unity-workspace.com`) to allow live multi-user editing of office documents:
* **Supported Formats**: Word (`.docx`, `.doc`, `.odt`), Excel (`.xlsx`, `.xls`, `.ods`), PowerPoint (`.pptx`, `.ppt`, `.odp`), Rich Text (`.rtf`).
* **WOPI Protocol**: Secure Web Application Open Platform Interface tokens are generated on-the-fly when opening a document.
* **Architecture**: The document iframe is embedded in `packages/web-app-preview/src/views/Preview.vue`.

### Preventing Preview Loading Flicker:
Earlier builds exhibited a double-loading glitch where the preview screen flashed multiple loading spinners. This was resolved by:
1. Retaining the parent component's `isLoading` state until Collabora posts the `App_LoadingStatus: Document_Loaded` message over the iframe `window.postMessage` bus.
2. Gracefully handling undefined `webDavPath` in `useAppFileHandling.ts` during rapid preview opens.

---

## 🎬 Video Previews & Large File Playback Performance

### Symptom:
When opening large video files (`.mov`, `.mp4` >500MB up to 10GB+), the preview is slow to buffer or hangs.

### Why This Occurs:

#### 1. Container Formats (`.mov` vs `.mp4`)
* **`.mov` (Apple QuickTime)** is produced by macOS screen recordings, iPhones, and cameras.
* Browsers (Chrome, Edge, Firefox) have limited native progressive decoding for `.mov` containers, especially with ProRes or non-baseline audio.

#### 2. The "moov atom" Metadata Location
* In standard video recording, the video index table (the **`moov atom`**) is written at the **very end of the file**.
* Because the browser needs the `moov atom` to know keyframe offsets, duration, and frame rates, it must download almost the entire multi-gigabyte file before rendering the first frame.

#### 3. Enterprise S3 vs. Transcoding Media Servers
* UDrive is an object storage platform storing files directly in MinIO S3 without background video transcoding.
* When previewing, the browser streams the raw original file across Cloudflare.

### Solution: Web-Optimized MP4 with `+faststart`
For instant web playback, transcode with `movflags +faststart`:
```bash
ffmpeg -i input.mov -c:v libx264 -pix_fmt yuv420p -c:a aac -movflags +faststart output.mp4
```
* **Why `+faststart` is instant**: It moves the `moov atom` to byte 0. The browser requests bytes `0-2097152` (first 2MB), renders the first frame, and begins playback in **under 1 second**.

---

## 🔍 Client Error Diagnostics

### 1. `net::ERR_BLOCKED_BY_CLIENT`
* **Root Cause**: Not a server error. Triggered by client-side AdBlockers (uBlock Origin, AdBlock Plus, Brave Shields) blocking telemetry or URLs with query parameters like `?preview=1` or `clientlog`.
* **Fix**: Whitelist `drive.unity-workspace.com` in your ad blocker.

### 2. `HTTP 425 Too Early - "File Processing"`
* **Root Cause**: Asynchronous background workers are still extracting metadata or generating thumbnails via NATS.
* **Fix**: Normal and transient. For files that get permanently stuck due to interrupted worker tasks, UDrive v1.4.15 introduces dedicated row Delete and Re-upload buttons.
