# 🦁 brave-hardening

> **Hardening del navegador Brave en macOS para máxima privacidad, seguridad y rendimiento.**  
> Un script. Tres capas. Cero telemetría.

<div align="center">

[![Versión](https://img.shields.io/badge/versión-4.0.0-blue?style=flat-square)](https://github.com/guicoradini/brave-hardening/releases)
[![macOS](https://img.shields.io/badge/macOS-13--15-lightgrey?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Brave](https://img.shields.io/badge/Brave-1.91+-orange?style=flat-square&logo=brave)](https://brave.com)
[![Licencia](https://img.shields.io/badge/licencia-MIT-green?style=flat-square)](LICENSE)

**🌐 Leer en otro idioma:**

[🇺🇸 English](README.md) &nbsp;|&nbsp; [🇧🇷 Português Brasileiro](README.pt-BR.md)

</div>

---

## 📋 Descripción general

`brave-hardening.sh` es un script Bash que aplica un conjunto completo de configuraciones de privacidad y rendimiento al navegador Brave en macOS. Funciona en tres capas independientes — desde políticas administradas a nivel del sistema hasta configuraciones por perfil de usuario.

Compatible con despliegue manual, SSH y soluciones MDM (Jamf, Mosyle, Kandji).

---

## 🏗️ Arquitectura: Tres Capas

```
┌─────────────────────────────────────────────────────┐
│  Capa 1 · plist (Sistema)                           │
│  /Library/Managed Preferences/com.brave.Browser.plist│
│  → Sobrevive reinstalaciones · Se aplica a todos    │
├─────────────────────────────────────────────────────┤
│  Capa 2 · Preferences (Por usuario)                 │
│  ~/Library/.../Brave-Browser/Default/Preferences    │
│  → Shields · Nueva pestaña · Privacy Sandbox        │
├─────────────────────────────────────────────────────┤
│  Capa 3 · Local State (Por usuario)                 │
│  ~/Library/.../Brave-Browser/Local State            │
│  → Listas de filtros · Flags · Rendimiento          │
└─────────────────────────────────────────────────────┘
```

### 🛡️ Capa 1 — plist (Sistema)

Escribe un archivo de política administrada que Brave lee al iniciar, aplicado a todos los usuarios del equipo. Sobrevive reinstalaciones del navegador.

| Categoría | Qué se configura |
|---|---|
| 🧹 **Eliminación de bloat** | Leo AI, Rewards, Wallet, VPN, Tor, News, Talk, imágenes patrocinadas — todo deshabilitado |
| 📡 **Telemetría** | P3A, stats ping, Web Discovery, Metrics Reporting — todos deshabilitados |
| 🔒 **Privacidad** | WebRTC → `disable_non_proxied_udp`, HTTPS-Only forzado, DNT y GPC habilitados, WebUSB y sensores bloqueados, First Party Ephemeral Storage activo, pagos y autocompletado de tarjetas deshabilitados |
| 🔐 **Seguridad** | Safe Browsing habilitado (protección estándar), filesystem read/write guard activo |
| ⚡ **Rendimiento** | High Efficiency Mode activo, Network Prediction deshabilitado, Background Mode deshabilitado |

### 👤 Capa 2 — Preferences (por usuario)

Modifica el archivo Preferences de cada usuario real del sistema. Se crea una copia de seguridad `.bak` antes de cualquier cambio.

- **Brave Shields:** modo Agresivo global (anuncios + rastreadores + cosmetic filtering)
- **Nueva pestaña:** fondo negro sólido (`#000000`), solo reloj — estadísticas, sitios frecuentes y barra de búsqueda deshabilitados
- **Privacy Sandbox:** Topics, FLEDGE y Ad Measurement deshabilitados
- **Sugerencias de búsqueda:** deshabilitadas
- **Inicio de sesión con Google:** deshabilitado
- **Pagos y autocompletado de tarjetas:** deshabilitados
- **WebRTC y DoNotTrack:** reforzados a nivel de perfil (complementa el plist)

### 📦 Capa 3 — Local State (por usuario)

Modifica el archivo Local State de cada usuario. También crea copia de seguridad `.bak`. Aquí es donde Brave almacena efectivamente las listas de filtros, flags y configuraciones de rendimiento.

| Categoría | Detalles |
|---|---|
| 📋 **Listas de filtros personalizadas** | uBlock Filters + Legitimate URL Shortener |
| 🌍 **Filtros regionales** | Brave Experimental, Annoyances, Cookie Notices, Twitch Adblock + listas nativas adicionales |
| 🚩 **Feature flags** | `brave-adblock-default-1p-blocking`, `enable-parallel-downloading`, `enable-quic`, `heuristic-memory-saver-mode` (Aggressive), `brave-adblock-cookie-list-opt-in` |
| ⚡ **Rendimiento** | Memory Saver Aggressive + Battery Saver |
| 📡 **P3A** | Telemetría de producto deshabilitada también en Local State |

> Las listas de filtros y flags existentes del usuario son **preservadas** — el script hace merge, nunca sobrescribe.

---

## 🚀 Cómo usar

> **Requiere `sudo`.** El script rechaza la ejecución sin privilegios de root.

```bash
# Aplica solo las políticas del sistema (plist)
sudo ./brave-hardening.sh

# Aplica solo las Preferences de cada usuario
sudo ./brave-hardening.sh --prefs

# Aplica solo el Local State de cada usuario
sudo ./brave-hardening.sh --local

# Aplica todo (recomendado)
sudo ./brave-hardening.sh --all

# Verifica el estado actual del hardening
sudo ./brave-hardening.sh --verify

# Deshace todos los cambios
sudo ./brave-hardening.sh --revert
```

---

## ✅ Verificación

La flag `--verify` inspecciona el estado actual y muestra una lista de verificación por usuario:

```
── Usuario: juan
  [Preferences]
    ✓  Shields Aggressive ads
    ✓  Shields Aggressive trackers
    ✓  Cosmetic filtering
    ✓  Privacy Sandbox off
    ✓  Search suggestions off
    ✓  Google Sign-In off
    ✓  Payments off
    ✓  WebRTC leak off
    ✓  NTP fondo negro
    ✓  NTP solo reloj
  [Local State]
    ✓  Custom filter lists (2)
    ✓  Regional filters (7)
    ✓  Flags (5/5)
    ✓  Memory Saver Aggressive
    ✓  Battery Saver
    ✓  P3A off
```

Para validación adicional dentro del navegador: `brave://policy` y `brave://settings/shields`.

---

## ↩️ Revertir

La flag `--revert` deshace los siguientes cambios:

- Elimina el plist del sistema
- Elimina las entradas de Shields (shieldsAds, trackers, cosmeticFilteringV2) de Preferences
- Elimina `list_subscriptions` y `regional_filters` del Local State

> Los flags y las configuraciones de rendimiento **no** se revierten. Para una restauración completa, utiliza las copias de seguridad `.bak` creadas junto a cada archivo modificado.

---

## 🔧 Requisitos

- `bash` 4+ (via `#!/usr/bin/env bash`)
- `python3` (disponible por defecto en macOS 12+)
- `plutil` (nativo de macOS)
- `dscl` (nativo de macOS)

---

## 🌐 Idiomas

| Idioma | Enlace |
|---|---|
| 🇺🇸 English | [README.md](README.md) |
| 🇧🇷 Português Brasileiro | [README.pt-BR.md](README.pt-BR.md) |
| 🇪🇸 Español | Estás aquí |

---

## 📄 Licencia

[MIT](LICENSE)
