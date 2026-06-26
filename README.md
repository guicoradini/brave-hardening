# brave-hardening

Script Bash para hardening do Brave Browser no macOS — privacidade, segurança e performance.

**Versão:** 4.0.0  
**Compatibilidade:** macOS 13–15, Brave 1.91+ (Chromium 149+)  
**Deploy:** manual, SSH, Jamf, Mosyle, Kandji

---

## O que faz

O script aplica configurações em três camadas independentes, do nível de sistema até o perfil de cada usuário.

### Camada 1 — plist (sistema)

Escreve `/Library/Managed Preferences/com.brave.Browser.plist` como política de sistema gerenciada. Sobrevive a reinstalações do Brave e se aplica a todos os usuários da máquina.

| Categoria | Configurações |
|---|---|
| **Bloat** | Leo AI, Rewards, Wallet, VPN, Tor, News, Talk, imagens patrocinadas — tudo desabilitado |
| **Telemetria** | P3A, stats ping, Web Discovery, Metrics Reporting — desabilitados |
| **Privacidade** | WebRTC → `disable_non_proxied_udp`, HTTPS-Only forçado, DNT, GPC, WebUSB bloqueado, sensores bloqueados, First Party Ephemeral Storage ativo, pagamentos e autofill de cartão desabilitados |
| **Segurança** | Safe Browsing habilitado (proteção padrão), filesystem read/write guard ativo |
| **Performance** | High Efficiency Mode, Network Prediction desabilitado, Background Mode desabilitado |

### Camada 2 — Preferences (por usuário)

Modifica `~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Preferences` de cada usuário real da máquina. Faz backup automático com extensão `.bak` antes de qualquer alteração.

- **Brave Shields:** modo Agressivo global para anúncios, trackers e cosmetic filtering
- **Nova aba:** fundo preto sólido (`#000000`), somente relógio (stats, top sites e search bar desabilitados)
- **Privacy Sandbox:** Topics, FLEDGE e Ad Measurement desabilitados
- **Sugestões de pesquisa:** desabilitadas
- **Google Sign-In:** desabilitado
- **Pagamentos e autofill de cartão:** desabilitados
- **WebRTC e DoNotTrack:** reforço em nível de perfil (backup do plist)

### Camada 3 — Local State (por usuário)

Modifica `~/Library/Application Support/BraveSoftware/Brave-Browser/Local State` de cada usuário. Também faz backup `.bak`. É onde o Brave efetivamente armazena filter lists, flags e tuning de performance.

| Categoria | Detalhes |
|---|---|
| **Custom filter lists** | [uBlock Filters](https://ublockorigin.github.io/uAssets/filters/filters.min.txt) + [Legitimate URL Shortener](https://raw.githubusercontent.com/DandelionSprout/adfilt/master/LegitimateURLShortener.txt) |
| **Regional filters** | Brave Experimental, Annoyances, Cookie Notices, Twitch Adblock + outras listas nativas habilitadas por UUID |
| **Browser flags** | `brave-adblock-default-1p-blocking`, `enable-parallel-downloading`, `enable-quic`, `heuristic-memory-saver-mode` (Aggressive), `brave-adblock-cookie-list-opt-in` |
| **Performance** | Memory Saver Aggressive (`aggressiveness: 2`) + Battery Saver |
| **P3A** | Telemetria de produto desabilitada também no Local State |

> As listas existentes do usuário são **preservadas** — o script apenas adiciona/atualiza as entradas necessárias.

---

## Opções de execução

```bash
# Aplica somente as políticas de sistema (plist)
sudo ./brave-hardening.sh

# Aplica somente as Preferences de cada usuário
sudo ./brave-hardening.sh --prefs

# Aplica somente o Local State de cada usuário
sudo ./brave-hardening.sh --local

# Aplica tudo: plist + Preferences + Local State
sudo ./brave-hardening.sh --all

# Verifica o estado atual do hardening
sudo ./brave-hardening.sh --verify

# Remove tudo que o script aplicou
sudo ./brave-hardening.sh --revert
```

> Requer `sudo`. O script recusa execução sem privilégios de root.

---

## Dependências

- `bash` 4+ (via `#!/usr/bin/env bash`)
- `python3` (disponível por padrão no macOS 12+)
- `plutil` (nativo do macOS)
- `dscl` (nativo do macOS)

---

## Comportamento de segurança

- O Brave é **encerrado automaticamente** (`killall "Brave Browser"`) antes de modificar Preferences ou Local State, para evitar que o browser sobrescreva as alterações ao fechar.
- Backups são criados com extensão `.bak` ao lado de cada arquivo modificado.
- O plist é validado com `plutil -lint` após a escrita; em caso de XML inválido, o script aborta com erro.
- Flags existentes no `browser.enabled_labs_experiments` são **preservadas** — o script faz union com as flags desejadas.

---

## Verificação

O comando `--verify` inspeciona o estado atual e exibe um checklist por usuário:

```
── Usuário: joao
  [Preferences]
    ✓  Shields Aggressive ads
    ✓  Shields Aggressive trackers
    ✓  Cosmetic filtering
    ✓  Privacy Sandbox off
    ✓  Search suggestions off
    ...
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

## Revert

O comando `--revert` desfaz as alterações:

- Remove o plist de sistema
- Remove as entradas de Shields (shieldsAds, trackers, cosmeticFilteringV2) das Preferences
- Remove `list_subscriptions` e `regional_filters` do Local State

> Flags e configurações de performance **não** são revertidas pelo `--revert`. Para restauração completa, use o backup `.bak`.
