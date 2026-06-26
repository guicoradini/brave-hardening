# 🦁 brave-hardening

> **Harden your Brave Browser on macOS for maximum privacy, security, and performance.**  
> One script. Three layers. Zero telemetry.

<div align="center">

[![Version](https://img.shields.io/badge/version-4.0.0-blue?style=flat-square)](https://github.com/guicoradini/brave-hardening/releases)
[![macOS](https://img.shields.io/badge/macOS-13--15-lightgrey?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Brave](https://img.shields.io/badge/Brave-1.91+-orange?style=flat-square&logo=brave)](https://brave.com)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)

**🌐 Read this in another language:**

[🇧🇷 Português Brasileiro](README.pt-BR.md) &nbsp;|&nbsp; [🇪🇸 Español](README.es.md)

</div>

---

## 📋 Overview

`brave-hardening.sh` is a Bash script that applies a comprehensive set of privacy and performance configurations to the Brave Browser on macOS. It works across three independent layers — from system-wide managed policies down to per-user profile settings.

Compatible with manual deployment, SSH, and MDM solutions (Jamf, Mosyle, Kandji).

---

## 🏗️ Architecture: Three Layers

```
┌─────────────────────────────────────────────────────┐
│  Layer 1 · plist (System)                           │
│  /Library/Managed Preferences/com.brave.Browser.plist│
│  → Survives reinstalls · Applies to all users       │
├─────────────────────────────────────────────────────┤
│  Layer 2 · Preferences (Per-user)                   │
│  ~/Library/.../Brave-Browser/Default/Preferences    │
│  → Shields · New Tab Page · Privacy Sandbox         │
├─────────────────────────────────────────────────────┤
│  Layer 3 · Local State (Per-user)                   │
│  ~/Library/.../Brave-Browser/Local State            │
│  → Filter lists · Flags · Performance tuning        │
└─────────────────────────────────────────────────────┘
```

### 🛡️ Layer 1 — System plist

Writes a managed policy file that Brave reads at startup, applied to all users on the machine.

| Category | What gets configured |
|---|---|
| 🧹 **Bloat removal** | Leo AI, Rewards, Wallet, VPN, Tor, News, Talk, sponsored images — all disabled |
| 📡 **Telemetry** | P3A, stats ping, Web Discovery, Metrics Reporting — all disabled |
| 🔒 **Privacy** | WebRTC → `disable_non_proxied_udp`, HTTPS-Only forced, DNT & GPC enabled, WebUSB & sensors blocked, First Party Ephemeral Storage enabled, payments & credit card autofill disabled |
| 🔐 **Security** | Safe Browsing enabled (standard), filesystem read/write guard active |
| ⚡ **Performance** | High Efficiency Mode on, Network Prediction off, Background Mode off |

### 👤 Layer 2 — Preferences (per user)

Modifies each real user's Preferences file. A `.bak` backup is created before any change.

- **Brave Shields:** Aggressive mode globally (ads + trackers + cosmetic filtering)
- **New Tab Page:** solid black background (`#000000`), clock only — stats, top sites, and search bar disabled
- **Privacy Sandbox:** Topics, FLEDGE, and Ad Measurement disabled
- **Search suggestions:** disabled
- **Google Sign-In:** disabled
- **Payments & credit card autofill:** disabled
- **WebRTC & DoNotTrack:** reinforced at profile level (backs up plist)

### 📦 Layer 3 — Local State (per user)

Modifies each user's Local State file. Also creates `.bak` backup. This is where Brave actually stores filter lists, feature flags, and performance settings.

| Category | Details |
|---|---|
| 📋 **Custom filter lists** | uBlock Filters + Legitimate URL Shortener |
| 🌍 **Regional filters** | Brave Experimental, Annoyances, Cookie Notices, Twitch Adblock + additional native lists |
| 🚩 **Feature flags** | `brave-adblock-default-1p-blocking`, `enable-parallel-downloading`, `enable-quic`, `heuristic-memory-saver-mode` (Aggressive), `brave-adblock-cookie-list-opt-in` |
| ⚡ **Performance** | Memory Saver Aggressive + Battery Saver |
| 📡 **P3A** | Product analytics disabled also at Local State level |

> Existing user filter lists and flags are **preserved** — the script merges, never overwrites.

---

## 🚀 Usage

> **Requires `sudo`.** The script will refuse to run without root privileges.

```bash
# Apply system policies only (plist)
sudo ./brave-hardening.sh

# Apply per-user Preferences only
sudo ./brave-hardening.sh --prefs

# Apply per-user Local State only
sudo ./brave-hardening.sh --local

# Apply everything (recommended)
sudo ./brave-hardening.sh --all

# Verify current hardening state
sudo ./brave-hardening.sh --verify

# Undo all changes
sudo ./brave-hardening.sh --revert
```

---

## ✅ Verify

The `--verify` flag inspects the current state and prints a checklist per user:

```
── User: john
  [Preferences]
    ✓  Shields Aggressive ads
    ✓  Shields Aggressive trackers
    ✓  Cosmetic filtering
    ✓  Privacy Sandbox off
    ✓  Search suggestions off
    ✓  Google Sign-In off
    ✓  Payments off
    ✓  WebRTC leak off
    ✓  Black NTP background
    ✓  NTP clock only
  [Local State]
    ✓  Custom filter lists (2)
    ✓  Regional filters (7)
    ✓  Flags (5/5)
    ✓  Memory Saver Aggressive
    ✓  Battery Saver
    ✓  P3A off
```

For additional validation inside the browser: `brave://policy` and `brave://settings/shields`.

---

## ↩️ Revert

The `--revert` flag undoes the following:

- Removes the system plist
- Removes Shields entries (shieldsAds, trackers, cosmeticFilteringV2) from Preferences
- Removes `list_subscriptions` and `regional_filters` from Local State

> Feature flags and performance settings are **not** reverted. For a full rollback, restore from the `.bak` files created alongside each modified file.

---

## 🔧 Requirements

- `bash` 4+ (via `#!/usr/bin/env bash`)
- `python3` (available by default on macOS 12+)
- `plutil` (macOS native)
- `dscl` (macOS native)

---

## 🌐 Languages

| Language | Link |
|---|---|
| 🇺🇸 English | You are here |
| 🇧🇷 Português Brasileiro | [README.pt-BR.md](README.pt-BR.md) |
| 🇪🇸 Español | [README.es.md](README.es.md) |

---

## 📄 License

[MIT](LICENSE)
