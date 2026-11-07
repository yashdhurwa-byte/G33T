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

---

## STAGE 2: Turntable UI, Offline Navigation, Notification Lyrics, & Dual Theme Engines

### 1. Digital Vinyl Platter & Now Playing UI
- Interactive spinning turntable/vinyl platter interface with continuous unidirectional looping (no reverse snap-backs on pause/seek/loop).
- Realistic vinyl grooves, specular sheen reflection, center circular album art label, and metallic spindle pin.
- Gesture controls: tap for play/pause, horizontal drag for scratching/manual rotation, and horizontal swipe/fling to skip tracks.
- Integrated synchronized lyrics view supporting both embedded Vorbis comments and local `.lrc` sidecars.

### 2. Custom Folder & Album Navigation
- Offline folder hierarchy browser with interactive breadcrumb navigation, SAF/storage indicators, and folder statistics.
- Responsive Album Grid view wired to local `sqflite` (`LibraryDatabase`) and SAF scanner with custom cover art caching via `CoverCacheManager`.

### 3. One UI Notification Lyrics Bridge
- Hooks into Android `MediaSession` and media notification metadata pipeline.
- Streams live synchronized lyric lines directly to the system media notification panel and Samsung One UI lock screen ticker.
- Gracefully restores base track metadata on pause or track switch.

### 4. Theme Engine Switcher
- Live settings toggle cleanly switching between:
  - **Engine A (Mornye Engine):** Pure Black AMOLED (`#000000`), Electric Violet (`#8B5CF6`), Stark White (`#FFFFFF`).
  - **Engine B (Material UI):** White background (`#FFFFFF`), Sakura Pink pills/cards (`#FCE4EC`), Deep Royal Purple accents (`#6A1B9A`), with `useDynamicColor: false`.
- Instant live updates across seekbars, pills, cards, and navigation bars without application restart.

### Validation Criteria
- `cargo check --workspace`: 0 errors, 0 warnings.
- `flutter analyze`: 0 errors, 0 warnings.

---

## STAGE 3: Real-Time Audio Telemetry & Offline Playback Analytics

### 1. Real-Time Audio & DAC Signal Telemetry
- Extracts live stream parameters from the Rust decoder, Android audio, Oboe, and USB DAC bit-perfect pipelines:
  - Codec & Format: FLAC, WAV, DSD, ALAC, Opus, MP3
  - Bit depth: 16-bit, 24-bit, 32-bit float, 1-bit DSD
  - Sample rate in kHz: 44.1 kHz, 48.0 kHz, 96.0 kHz, 192.0 kHz, 384.0 kHz, DSD64/128/256
  - Instantaneous / average bitrate in kbps
  - Active hardware output route: USB DAC (Bit-Perfect Direct), Oboe / AudioTrack Hi-Res, 3.5mm Headphone Jack, Internal Speaker, Bluetooth LDAC/aptX
- Rendered in a clean, interactive, and toggleable technical telemetry HUD/pill on the Now Playing screen.

### 2. Offline Playback Telemetry & Analytics Engine
- Strictly local SQLite (`sqflite`) telemetry engine (`playback_telemetry.db`).
- Logs verified play counts (>= 30s or >= 50% threshold), cumulative listening time, and completion ratios vs. early skips.
- Tracks most-played tracks, albums, and directories/folders without any network calls.
- Classifies audio quality distribution (Hi-Res 24-bit/96kHz+, CD 16-bit Lossless, Lossy).

### 3. Telemetry Dashboard Screen
- Dedicated Listening Telemetry & Analytics dashboard screen (`TelemetryDashboardScreen`).
- Visual breakdowns of listening time, verified plays, completion-to-skip ratios, top tracks, top albums, top folders, and signal quality distribution.
- Dynamically adapts to both:
  - **Engine A (Mornye Engine):** AMOLED Pure Black (`#000000`), Electric Violet (`#8B5CF6`), Stark White (`#FFFFFF`).
  - **Engine B (Material UI):** White background (`#FFFFFF`), Sakura Pink cards (`#FCE4EC`), Deep Royal Purple accents (`#6A1B9A`).

### Validation Criteria
- `cargo check --workspace`: 0 errors, 0 warnings.
- `flutter analyze`: 0 errors, 0 warnings.

---

## STAGE 4: Full-Screen Landscape Desktop Mode & Theme Synchronization

### 1. Full-Screen Landscape Desktop Mode (Dopamine-Inspired)
- Immersive, full-screen desktop mode layout (`DopamineDesktopPlayer`) inspired by Dopamine's layout:
  - Large digital spinning vinyl platter (`TurntablePlatter`) with continuous monotonic unidirectional rotation, realistic grooves, specular sheen reflection, center circular album art label, metallic spindle pin, and gesture controls (scratching, tap-to-pause, fling to skip).
  - Centered live hardware audio & DAC signal telemetry HUD pill (`AudioSignalTelemetryHud`) displaying codec/format, sample rate (kHz), bit depth, instantaneous bitrate (kbps), active hardware output route, and pulsing bit-perfect LED.
  - Full real-time synchronized lyrics ticker (`PlayerLyricsSection`) with line-by-line highlight, smooth scrolling, animated words, and tap-to-seek timestamp capabilities, switchable to Up Next queue.
  - Top utility bar with close/minimize, fullscreen toggle, audio output device selector (`AudioOutputButton`), equalizer shortcut, and Lyrics/Queue switcher capsule.
  - Seamless orientation handling for tablet and desktop form factors (automatic presentation on landscape rotation and tablet wide screens, plus explicit one-tap Full-Screen Desktop Mode toggle from portrait).

### 2. Dual Theme Engine Synchronization
- Complete layout styling dynamically bound to the active engine:
  - **Engine A (Mornye Engine):** Pure AMOLED Black (`#000000`), Electric Violet (`#8B5CF6`) primary accents and active highlights, Stark White (`#FFFFFF`) typography and icons.
  - **Engine B (Google Material UI):** Crisp White (`#FFFFFF`) background, Sakura Pink (`#FCE4EC`) cards and pills, Deep Royal Purple (`#6A1B9A`) primary accents and typography, with `useDynamicColor: false`.

### Validation Criteria
- `cargo check --workspace`: 0 errors, 0 warnings.
- `flutter analyze`: 0 errors, 0 warnings.

---

## STAGE 5: Spatial Vinyl UI Refactor & Final Verification

### 1. Spatial Vinyl & Cover Flow Layout
- **High-Fidelity Rotating Vinyl Platter (`TurntablePlatter`)**:
  - Concentric microgroove CustomPainters with dual opposing light cones, beveled outer rim, run-out groove, center circular album-art clipping mask, and metallic spindle pin.
  - Animated tonearm physics: dynamic tracking angle sweep responding to playback position ($0\% \to 100\%$), realistic needle drop damping with spring oscillation (`Curves.easeOutBack`), and spatial cast shadow onto the vinyl record.
- **Cascading Cover Flow / 3D Album Selection Carousel (`SpatialCoverFlow`)**:
  - Matrix4 3D perspective projection (`setEntry(3, 2, 0.0018)`), Y-axis rotation, Z-depth translation, and depth falloff.
  - Realistic mirror floor reflection with gradient transparency mask.
  - Integrated into both play queue browsing and local offline SAF album library browsing (`AlbumGridScreen`).
- **Floating Glass Control Dock Pills (`FloatingGlassControlDock`)**:
  - Real-time frosted glass blur via `BackdropFilter` (`sigmaX: 18, sigmaY: 18`).
  - Houses interactive seekbars, complete tactile transport controls, volume control, and embedded live DAC telemetry badge.

### 2. Backend & Engine Binding
- Direct connection to the Rust FFI audio decoder and live telemetry streams.
- Live responsiveness and dynamic synchronization across:
  - **Theme Engine A (Mornye):** `#000000` AMOLED Black, `#8B5CF6` Electric Violet accents, `#FFFFFF` Stark White text/controls.
  - **Theme Engine B (Google Material UI):** `#FFFFFF` background, `#FCE4EC` Sakura Pink glass cards/pills, `#6A1B9A` Deep Royal Purple accents, with `useDynamicColor: false`.

### Validation Criteria
- `cargo check --workspace`: 0 errors, 0 warnings.
- `flutter analyze`: 0 errors, 0 warnings.

---

## STAGE 6: Home Screen Widget & Engine A Color Tuning

### 1. Engine A Color Update
- **Theme Engine A (Mornye Engine) Tuning**:
  - AMOLED Black background: `#000000`
  - Electric Violet accents: `#8B5CF6`
  - Warm Soft Beige: `#F5F0EB` replacing stark white for primary typography, borders, and tactile highlights.
- **Theme Engine B (Google Material UI)**: Kept unchanged (`#FFFFFF` background, `#FCE4EC` Sakura pink cards/pills, `#6A1B9A` Deep Royal Purple accents).

### 2. Native Android Home Screen Widget (`AppWidgetProvider`)
- Custom home screen widget styled after floating card reference design:
  - **Frosted Glass Container Card**: Dynamically matched to the active theme engine (`#0D0D12` dark frosted glass for Engine A, `#FCE4EC` for Engine B).
  - **Top Section**: Track title, artist name, and mini FLAC telemetry/waveform badge (`FLAC • 96kHz / 24-bit`).
  - **Center Section**: Live-synced lyrics text box with quotation marks (`“...”`) displaying the active lyric line in warm beige / electric violet.
  - **Bottom Section**: Compact quick-action playback control pills (`widget_player_controls`: previous, play/pause, next).
  - **Service & Notification Wiring**: Live synchronized lyric line updates from `NotificationLyricsBridge` stream directly to the widget, updating the home screen in real-time alongside Samsung One UI and Android MediaSession notifications.

### Validation Criteria
- `cargo check --workspace`: 0 errors, 0 warnings.
- `flutter analyze`: 0 errors, 0 warnings.
