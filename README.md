# MAKASNA Remote Broadcast Controller (Android)

<p align="center">
  <img src="assets/images/logo.png" alt="MAKASNA Remote" width="96" height="96" />
</p>

<p align="center">
  <b>Android Remote Controller &amp; Ingest Signal Monitor for Makasna Live Video Transport Gateway</b><br>
  <i>Control Master Deck ISO recording, monitor field SRT signals, inspect audio digital clipping, and switch broadcast routes directly from your smartphone.</i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.24+-02569B?style=flat-square" alt="Flutter" />
  <img src="https://img.shields.io/badge/Android-SDK%2024+-3DDC84?style=flat-square" alt="Android" />
  <img src="https://img.shields.io/badge/SRT-Video%20Transport-00E5FF?style=flat-square" alt="SRT" />
  <img src="https://img.shields.io/badge/Status-Production%20Ready-10B981?style=flat-square" alt="Status" />
</p>

---

## Key Features

1. **Dynamic Server Setup & Persistent Session:**
   * Enter any Gateway Server IP or Hostname, HTTP API Port (default: `8080`), and SRT Port (default: `8890`).
   * **Ping Handshake Test:** Real-time reachability and latency diagnostic before launching session.
   * **Remember Login Session (Auto-Connect):** Credentials safely stored in Android keystore/encrypted preferences for instant auto-login.

2. **Ingest Signal & Listener Monitor:**
   * **Ingest Throughput:** Real-time bitrate RX (`↓ X.XX Mbps`), packet loss percentage, and RTT round-trip latency.
   * **Publishers List:** Real-time tracking of connected upstream camera encoders (`publish:STREAM_ID`).
   * **Active Readers List:** Monitor downstream studio playout receivers (`read:STREAM_ID`), IP addresses, ports, and transmitted data volume.
   * **1-Click Actions:** Copy SRT URLs to clipboard and instantly convert active feeds into broadcast routes.

3. **Master Deck ISO Recorder Remote:**
   * **Hardware Tally Lamp:** Animated broadcast tally glowing red during active recording `[● REC ACTIVE]` and dim slate during standby `[■ STANDBY]`.
   * **Hardware-Accelerated Video Monitor:** ExoPlayer 16:9 confidence player with low-latency HLS feed fallback.
   * **OSD LCD Timecode:** Monospace real-time running timecode `00:00:00:00` and stream metadata.
   * **Tactile Controls:** Dedicated **RECORD** and **STOP** buttons with safety confirmations.
   * **Container & Format Controls:** Universal MP4 and Apple QuickTime MOV, with selectable bitrates (Passthrough, 2.5–16 Mbps, or Custom kbps) and resolutions.

4. **Multi-Track Audio VU Meter & Digital Clip Alert:**
   * 2-Bar and 4-Bar audio monitoring with selectable dBVU (-20 to +3 VU) and dBFS (-60 to 0 dBFS) scales.
   * Instant red **`DIGITAL CLIP!`** indicator if audio signal exceeds 0 dBFS to prevent distortion.

5. **Broadcast Route Management & Failover:**
   * Full CRUD operations: Create, edit, activate, deactivate, and delete routes.
   * Hot-standby failover configuration with Primary and Secondary source pairing.
   * Multi-destination fan-out management (SRT, RTMP, and local relays).

---

## Build & Installation

### Prerequisites
* Flutter SDK `>= 3.24.0`
* Android SDK 34 (Android 7.0 Nougat to Android 14+)
* OpenJDK 17

### Building Release APK

```bash
# Fetch Flutter packages
flutter pub get

# Compile release APK
flutter build apk --release
```

The compiled release binary is located at:
```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## Operational Guide

For full operational procedures in Indonesian, refer to **[PANDUAN.md](PANDUAN.md)**.

## License

Proprietary — Developed by **Makasna Broadcast Infrastructure**. All rights reserved.
