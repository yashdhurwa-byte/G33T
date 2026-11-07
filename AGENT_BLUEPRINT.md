# AGENT_BLUEPRINT.md

## Overview
G33T (Mornye) is a high-performance, audiophile-grade mobile music utility built with Flutter and Rust for Android. This blueprint outlines the engineering stages for refining the application into a lean, offline-first local audio player with bit-perfect playback and distinct theme engines.

---

## STAGE 1: Core Lean Transformation & Audio Extraction

### 1. GitHub Actions Optimization (.github/workflows/)
- Focus the release workflow strictly on Android **arm64-v8a** architecture.
- Eliminate desktop (Windows, macOS, Linux) and iOS builds from release jobs.
- Implement comprehensive caching (Gradle, Android NDK, Rust toolchain/cargo cache, Flutter SDK, Pub dependencies) ensuring end-to-end release builds complete in under 6 minutes.

### 2. Strip Remote Extensions, Protocols, & Services
- Remove online streaming/downloading extensions and extension registries from the codebase.
- Strip download workers and remote sync infrastructure.
- Remove network file protocols: SMB (`dart_smb2`), WebDAV, and Subsonic.
- Remove Discord Rich Presence (RPC / `mornye_discord`).
- Remove desktop pairing / local link services (`bonsoir`, desktop link).
- Clean up navigation routes (`go_router`) to remove unreachable online/pairing/extension screens.
- **Retain**: Local folder scanning via Storage Access Framework (`SAF`) and `sqflite`, Android audio pipeline (`audioplayers_android`), Oboe/USB DAC bit-perfect pipelines, and `native_palette`.

### 3. Audio Metadata Extraction & Lyrics Export
- **METADATA_BLOCK_PICTURE Cover Art Extractor**:
  - Implement parsing of raw FLAC / Ogg / Opus `METADATA_BLOCK_PICTURE` binary structures in Rust (`mornye-core` / `mornye-mobile`).
  - Handle base64-encoded Vorbis comment picture blocks and raw binary FLAC picture metadata blocks (MIME, description, dimensions, color depth, image data).
  - Expose API to Dart via PlatformBridge for extracting cover art directly into raw byte buffers or image files.
- **Offline Vorbis-to-.lrc Lyrics Exporter**:
  - Read embedded Vorbis comment tags (`LYRICS`, `SYNCEDLYRICS`, `UNSYNCEDLYRICS`).
  - Export synchronized / plain lyrics to sidecar `.lrc` files offline beside audio files or content URIs.

### 4. Dual Theme Engine Locking (lib/theme/)
- **Engine A: Mornye Engine**
  - Surface / Background: Pure Black (`#000000`)
  - Accent / Primary: Electric Violet (`#8B5CF6`)
  - Foreground / Contrast: Stark White (`#FFFFFF`)
- **Engine B: Google Material UI**
  - Background: White (`#FFFFFF`)
  - Cards / Pills: Sakura Pink (`#FCE4EC`)
  - Accents / Highlights: Deep Royal Purple (`#6A1B9A`)
  - Dynamic Color: Explicitly locked to `useDynamicColor: false`.

### Validation Criteria
- `cargo check`: 0 errors across the Rust workspace.
- `flutter analyze`: 0 errors across the Flutter codebase.
- Commit and push to repository upon passing all checks.

---

## STAGE 2: (Upcoming)
- Advanced audiophile playback pipeline calibration, offline caching enhancements, and extended playlist management.
