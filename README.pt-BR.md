# 🦁 brave-hardening

> **Harden do Brave Browser no macOS para máxima privacidade, segurança e performance.**  
> Um script. Três camadas. Zero telemetria.

<div align="center">

[![Versão](https://img.shields.io/badge/versão-4.0.0-blue?style=flat-square)](https://github.com/guicoradini/brave-hardening/releases)
[![macOS](https://img.shields.io/badge/macOS-13--15-lightgrey?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Brave](https://img.shields.io/badge/Brave-1.91+-orange?style=flat-square&logo=brave)](https://brave.com)
[![Licença](https://img.shields.io/badge/licença-MIT-green?style=flat-square)](LICENSE)

**🌐 Leia em outro idioma:**

[🇺🇸 English](README.md) &nbsp;|&nbsp; [🇪🇸 Español](README.es.md)

</div>

---

## 📋 Visão Geral

`brave-hardening.sh` é um script Bash que aplica um conjunto abrangente de configurações de privacidade e performance ao Brave Browser no macOS. Funciona em três camadas independentes — desde políticas gerenciadas em nível de sistema até configurações por perfil de usuário.

Compatível com deploy manual, SSH e soluções MDM (Jamf, Mosyle, Kandji).

---

## 🏗️ Arquitetura: Três Camadas

```
┌─────────────────────────────────────────────────────┐
│  Camada 1 · plist (Sistema)                         │
│  /Library/Managed Preferences/com.brave.Browser.plist│
│  → Sobrevive a reinstalações · Aplica a todos       │
├─────────────────────────────────────────────────────┤
│  Camada 2 · Preferences (Por usuário)               │
│  ~/Library/.../Brave-Browser/Default/Preferences    │
│  → Shields · Nova aba · Privacy Sandbox             │
├─────────────────────────────────────────────────────┤
│  Camada 3 · Local State (Por usuário)               │
│  ~/Library/.../Brave-Browser/Local State            │
│  → Filter lists · Flags · Performance               │
└─────────────────────────────────────────────────────┘
```

### 🛡️ Camada 1 — plist (Sistema)

Escreve um arquivo de política gerenciada que o Brave lê ao iniciar, aplicado a todos os usuários da máquina. Sobrevive a reinstalações do browser.

| Categoria | O que é configurado |
|---|---|
| 🧹 **Remoção de bloat** | Leo AI, Rewards, Wallet, VPN, Tor, News, Talk, imagens patrocinadas — tudo desabilitado |
| 📡 **Telemetria** | P3A, stats ping, Web Discovery, Metrics Reporting — todos desabilitados |
| 🔒 **Privacidade** | WebRTC → `disable_non_proxied_udp`, HTTPS-Only forçado, DNT e GPC habilitados, WebUSB e sensores bloqueados, First Party Ephemeral Storage ativo, pagamentos e autofill de cartão desabilitados |
| 🔐 **Segurança** | Safe Browsing habilitado (proteção padrão), filesystem read/write guard ativo |
| ⚡ **Performance** | High Efficiency Mode ativo, Network Prediction desabilitado, Background Mode desabilitado |

### 👤 Camada 2 — Preferences (por usuário)

Modifica o arquivo Preferences de cada usuário real da máquina. Um backup `.bak` é criado antes de qualquer alteração.

- **Brave Shields:** modo Agressivo global (anúncios + trackers + cosmetic filtering)
- **Nova aba:** fundo preto sólido (`#000000`), somente relógio — stats, top sites e search bar desabilitados
- **Privacy Sandbox:** Topics, FLEDGE e Ad Measurement desabilitados
- **Sugestões de pesquisa:** desabilitadas
- **Google Sign-In:** desabilitado
- **Pagamentos e autofill de cartão:** desabilitados
- **WebRTC e DoNotTrack:** reforçados em nível de perfil (complementa o plist)

### 📦 Camada 3 — Local State (por usuário)

Modifica o arquivo Local State de cada usuário. Também cria backup `.bak`. É aqui que o Brave efetivamente armazena filter lists, flags de recursos e configurações de performance.

| Categoria | Detalhes |
|---|---|
| 📋 **Custom filter lists** | uBlock Filters + Legitimate URL Shortener |
| 🌍 **Filtros regionais** | Brave Experimental, Annoyances, Cookie Notices, Twitch Adblock + listas nativas adicionais |
| 🚩 **Feature flags** | `brave-adblock-default-1p-blocking`, `enable-parallel-downloading`, `enable-quic`, `heuristic-memory-saver-mode` (Aggressive), `brave-adblock-cookie-list-opt-in` |
| ⚡ **Performance** | Memory Saver Aggressive + Battery Saver |
| 📡 **P3A** | Telemetria de produto desabilitada também no Local State |

> Filter lists e flags existentes do usuário são **preservadas** — o script faz merge, nunca sobrescreve.

---

## 🚀 Como usar

> **Requer `sudo`.** O script recusa execução sem privilégios de root.

```bash
# Aplica somente as políticas de sistema (plist)
sudo ./brave-hardening.sh

# Aplica somente as Preferences de cada usuário
sudo ./brave-hardening.sh --prefs

# Aplica somente o Local State de cada usuário
sudo ./brave-hardening.sh --local

# Aplica tudo (recomendado)
sudo ./brave-hardening.sh --all

# Verifica o estado atual do hardening
sudo ./brave-hardening.sh --verify

# Desfaz todas as alterações
sudo ./brave-hardening.sh --revert
```

---

## ✅ Verificação

A flag `--verify` inspeciona o estado atual e exibe um checklist por usuário:

```
── Usuário: joao
  [Preferences]
    ✓  Shields Aggressive ads
    ✓  Shields Aggressive trackers
    ✓  Cosmetic filtering
    ✓  Privacy Sandbox off
    ✓  Search suggestions off
    ✓  Signin Google off
    ✓  Payments off
    ✓  WebRTC leak off
    ✓  NTP fundo preto
    ✓  NTP só relógio
  [Local State]
    ✓  Custom filter lists (2)
    ✓  Regional filters (7)
    ✓  Flags (5/5)
    ✓  Memory Saver Aggressive
    ✓  Battery Saver
    ✓  P3A off
```

Para validação adicional dentro do browser: `brave://policy` e `brave://settings/shields`.

---

## ↩️ Reverter

A flag `--revert` desfaz as seguintes alterações:

- Remove o plist de sistema
- Remove as entradas de Shields (shieldsAds, trackers, cosmeticFilteringV2) das Preferences
- Remove `list_subscriptions` e `regional_filters` do Local State

> Flags e configurações de performance **não** são revertidas. Para restauração completa, use os backups `.bak` criados ao lado de cada arquivo modificado.

---

## 🔧 Dependências

- `bash` 4+ (via `#!/usr/bin/env bash`)
- `python3` (disponível por padrão no macOS 12+)
- `plutil` (nativo do macOS)
- `dscl` (nativo do macOS)

---

## 🌐 Idiomas

| Idioma | Link |
|---|---|
| 🇺🇸 English | [README.md](README.md) |
| 🇧🇷 Português Brasileiro | Você está aqui |
| 🇪🇸 Español | [README.es.md](README.es.md) |

---

## 📄 Licença

[MIT](LICENSE)
