#!/usr/bin/env bash
# =============================================================================
# brave-hardening.sh v4.0.0
# Brave Browser hardening para macOS — privacidade + performance
# Compatível com: deploy manual, SSH, Jamf, Mosyle, Kandji
#
# Uso:
#   sudo ./brave-hardening.sh           # aplica políticas de sistema (plist)
#   sudo ./brave-hardening.sh --prefs   # aplica Preferences por usuário
#   sudo ./brave-hardening.sh --local   # aplica Local State por usuário
#   sudo ./brave-hardening.sh --all     # aplica tudo
#   sudo ./brave-hardening.sh --verify  # verifica estado
#   sudo ./brave-hardening.sh --revert  # remove tudo
#
# CAMADAS:
#   1. plist       → /Library/Managed Preferences/com.brave.Browser.plist
#   2. Preferences → ~/Library/.../Brave-Browser/Default/Preferences
#   3. Local State → ~/Library/.../Brave-Browser/Local State
#      (filter lists, regional filters, flags, performance — ficam aqui)
#
# Testado: macOS 13-15, Brave 1.91+ (Chromium 149+)
# =============================================================================

set -euo pipefail

PLIST_DIR="/Library/Managed Preferences"
PLIST_PATH="${PLIST_DIR}/com.brave.Browser.plist"
BRAVE_BASE="Library/Application Support/BraveSoftware/Brave-Browser"
BRAVE_PREFS="${BRAVE_BASE}/Default/Preferences"
BRAVE_LOCAL="${BRAVE_BASE}/Local State"
SCRIPT_VERSION="4.0.0"
LOG_PREFIX="[brave-hardening]"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}${LOG_PREFIX}${NC} $*"; }
ok()   { echo -e "${GREEN}${LOG_PREFIX} OK${NC} $*"; }
warn() { echo -e "${YELLOW}${LOG_PREFIX} WARN${NC} $*"; }
err()  { echo -e "${RED}${LOG_PREFIX} ERR${NC} $*" >&2; }

require_root() { [[ $EUID -eq 0 ]] || { err "Rode com sudo: sudo $0"; exit 1; }; }
brave_is_running() { pgrep -x "Brave Browser" &>/dev/null; }
kill_brave() {
  if brave_is_running; then
    log "Fechando Brave Browser..."
    killall "Brave Browser" 2>/dev/null || true
    sleep 2
  fi
}
get_real_users() {
  dscl . list /Users | grep -v '^_' | grep -vE '^(root|daemon|nobody|Guest)$' || true
}
get_home() { dscl . read "/Users/$1" NFSHomeDirectory 2>/dev/null | awk '{print $2}' || echo ""; }

# =============================================================================
# CAMADA 1: plist — políticas de sistema (root, sobrevive a reinstall)
# =============================================================================
cmd_apply() {
  log "Aplicando políticas de sistema (plist)..."
  mkdir -p "$PLIST_DIR"
  cat > "$PLIST_PATH" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <!-- BRAVE ORIGIN: remove bloat e monetização -->
  <key>BraveAIChatEnabled</key>             <false/>
  <key>BraveRewardsDisabled</key>           <true/>
  <key>BraveWalletDisabled</key>            <true/>
  <key>BraveVPNDisabled</key>               <true/>
  <key>TorDisabled</key>                    <true/>
  <key>BraveNewsDisabled</key>              <true/>
  <key>BraveTalkDisabled</key>              <true/>
  <key>BraveNewTabPageShowSponsoredImagesBackgroundImage</key> <false/>

  <!-- TELEMETRIA -->
  <key>BraveP3AEnabled</key>                <false/>
  <key>BraveStatsPingEnabled</key>          <false/>
  <key>BraveWebDiscoveryEnabled</key>       <false/>
  <key>MetricsReportingEnabled</key>        <false/>

  <!-- PRIVACIDADE -->
  <key>WebRtcIPHandlingPolicy</key>         <string>disable_non_proxied_udp</string>
  <key>HttpsOnlyMode</key>                  <string>force_enabled</string>
  <key>PaymentMethodQueryEnabled</key>      <false/>
  <key>AutofillCreditCardEnabled</key>      <false/>
  <key>EnableDoNotTrack</key>               <true/>
  <key>GlobalPrivacyControlEnabled</key>    <true/>
  <key>DefaultWebUsbGuardSetting</key>      <integer>2</integer>
  <key>DefaultSensorsSetting</key>          <integer>2</integer>
  <key>BraveFirstPartyEphemeralStorage</key><true/>

  <!-- SEGURANÇA -->
  <key>SafeBrowsingEnabled</key>            <true/>
  <key>SafeBrowsingProtectionLevel</key>    <integer>1</integer>
  <key>DefaultFileSystemReadGuardSetting</key>  <integer>2</integer>
  <key>DefaultFileSystemWriteGuardSetting</key> <integer>2</integer>

  <!-- PERFORMANCE -->
  <key>HighEfficiencyModeEnabled</key>      <true/>
  <key>NetworkPredictionOptions</key>       <integer>2</integer>
  <key>BackgroundModeEnabled</key>          <false/>
</dict>
</plist>
PLIST_EOF

  chmod 644 "$PLIST_PATH"
  chown root:wheel "$PLIST_PATH"
  plutil -lint "$PLIST_PATH" &>/dev/null && ok "plist aplicado e validado" || { err "XML inválido"; exit 1; }
}

# =============================================================================
# CAMADA 2: Preferences — configurações de perfil por usuário
# =============================================================================
cmd_prefs() {
  log "Aplicando Preferences por usuário..."
  kill_brave

  local applied=0 skipped=0
  while IFS= read -r user; do
    local home; home=$(get_home "$user")
    [[ -z "$home" || ! -d "$home" ]] && continue
    local path="${home}/${BRAVE_PREFS}"
    if [[ ! -f "$path" ]]; then
      warn "Preferences não encontrado para: ${user}"; ((skipped++)) || true; continue
    fi
    log "Preferences → ${user}"

    python3 << PYEOF
import json, shutil, time

path = "${path}"
shutil.copy2(path, path + ".bak")

with open(path) as f:
    p = json.load(f)

EPOCH_DIFF = 11644473600
ts = str(int((time.time() + EPOCH_DIFF) * 1_000_000))

ex = p.setdefault("profile", {}) \
      .setdefault("content_settings", {}) \
      .setdefault("exceptions", {})

# Shields — Aggressive global (setting=2)
ex.setdefault("shieldsAds",           {})["*,*"] = {"last_modified": ts, "setting": 2}
ex.setdefault("trackers",             {})["*,*"] = {"last_modified": ts, "setting": 2}
ex.setdefault("cosmeticFilteringV2",  {})["*,*"] = {"last_modified": ts, "setting": {"cosmeticFilteringV2": 1}}

# Brave Shields advanced view
p.setdefault("brave", {}).setdefault("shields", {})["advanced_view_enabled"] = True

# Nova aba — fundo preto sólido, só relógio
p["brave"].setdefault("new_tab_page", {}).update({
    "background": {
        "random": False,
        "selected_value": "#000000",
        "type": "color"
    },
    "show_background_image": True,
    "show_clock": True,
    "show_stats": False,
})

# Search bar da nova aba off
p["brave"].setdefault("brave_search", {})["show-ntp-search"] = False

# Top sites (shortcuts) off — "shortcust" e typo do proprio Brave
p.setdefault("ntp", {}).update({
    "shortcust_visible": False,
    "num_personal_suggestions": 0,
})

# Privacy Sandbox — tudo off
p.setdefault("privacy_sandbox", {}).update({
    "first_party_sets_enabled": False,
    "first_party_sets_data_access_allowed_initialized": True,
})
p["privacy_sandbox"].setdefault("m1", {}).update({
    "ad_measurement_enabled": False,
    "fledge_enabled": False,
    "topics_enabled": False,
})

# Search suggestions off
p.setdefault("search", {})["suggest_enabled"] = False

# Google Sign-In off
p.setdefault("signin", {})["allowed"] = False

# Payments off
p.setdefault("payments", {})["can_make_payment_enabled"] = False

# Autofill cartão off
p.setdefault("autofill", {})["credit_card_enabled"] = False

# DoNotTrack + WebRTC (backup do plist)
p["enable_do_not_track"] = True
p.setdefault("webrtc", {})["ip_handling_policy"] = "disable_non_proxied_udp"

with open(path, "w") as f:
    json.dump(p, f, separators=(",", ":"))
print("  OK")
PYEOF
    [[ $? -eq 0 ]] && { ok "Preferences → ${user}"; ((applied++)) || true; } \
                   || { err "Falha → ${user}"; ((skipped++)) || true; }
  done < <(get_real_users)
  log "Preferences: ${applied} OK, ${skipped} ignorados"
}

# =============================================================================
# CAMADA 3: Local State — filter lists, regional filters, flags, performance
# Confirmado pelo Local State do Gui:
#   - list_subscriptions: URLs das custom filter lists ficam AQUI (não em Preferences)
#   - regional_filters: UUIDs das listas nativas do Brave ficam AQUI
#   - browser.enabled_labs_experiments: flags ficam AQUI
#   - performance_tuning: Memory Saver Aggressive fica AQUI
# =============================================================================
cmd_local() {
  log "Aplicando Local State por usuário..."
  kill_brave

  local applied=0 skipped=0
  while IFS= read -r user; do
    local home; home=$(get_home "$user")
    [[ -z "$home" || ! -d "$home" ]] && continue
    local path="${home}/${BRAVE_LOCAL}"
    if [[ ! -f "$path" ]]; then
      warn "Local State não encontrado para: ${user}"; ((skipped++)) || true; continue
    fi
    log "Local State → ${user}"

    python3 << PYEOF
import json, shutil, time

path = "${path}"
shutil.copy2(path, path + ".bak")

with open(path) as f:
    ls = json.load(f)

EPOCH_DIFF = 11644473600
ts = str(int((time.time() + EPOCH_DIFF) * 1_000_000))

# ----------------------------------------------------------------
# CUSTOM FILTER LISTS (URLs)
# Ficam em brave.ad_block.list_subscriptions no Local State
# ----------------------------------------------------------------
ls.setdefault("brave", {}).setdefault("ad_block", {})

new_subs = {
    "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/LegitimateURLShortener.txt": {
        "enabled": True,
        "expires": 12,
        "homepage": "https://github.com/DandelionSprout/adfilt/discussions/163",
        "last_successful_update_attempt": ts,
        "last_update_attempt": ts
    },
    "https://ublockorigin.github.io/uAssets/filters/filters.min.txt": {
        "enabled": True,
        "expires": 120,
        "last_successful_update_attempt": ts,
        "last_update_attempt": ts,
        "title": "uBlock filters"
    }
}

existing_subs = ls["brave"]["ad_block"].get("list_subscriptions", {})
# Preserva listas extras que o usuário já tenha, adiciona/atualiza as nossas
existing_subs.update(new_subs)
ls["brave"]["ad_block"]["list_subscriptions"] = existing_subs

# ----------------------------------------------------------------
# REGIONAL FILTERS (listas nativas do Brave por UUID)
# Replicando exatamente o setup confirmado pelo Gui
# ----------------------------------------------------------------
regional = {
    "564C3B75-8731-404C-AD7C-5683258BA0B0": {"enabled": True},   # Brave Experimental
    "67E792D4-AE03-4D1A-9EDE-80E01C81F9B8": {"enabled": True},   # Annoyances
    "78672887-A098-4D2C-B0CB-A3DEC4834DA7": {"enabled": True},   # Cookie Notices
    "7911A1CB-304E-4CDB-ABB3-E2A94A37E4DD": {"enabled": True},   # Twitch Adblock
    "CC98E4BA-9257-4386-A1BC-1BBF6980324F": {"enabled": False},  # (desativado pelo Gui)
    "E2FA7D98-0BD5-493E-8AF4-950604ADE9CB": {"enabled": True},
    "F61D6B7B-4110-4EA4-9C81-38FB4CE90AEC": {"enabled": True},
}
existing_regional = ls["brave"]["ad_block"].get("regional_filters", {})
existing_regional.update(regional)
ls["brave"]["ad_block"]["regional_filters"] = existing_regional

# checked_all_default_regions garante que o Brave não vai sobrescrever
ls["brave"]["ad_block"]["checked_all_default_regions"] = True

# ----------------------------------------------------------------
# BROWSER FLAGS (brave://flags)
# Ficam em browser.enabled_labs_experiments no Local State
# ----------------------------------------------------------------
desired_flags = {
    "brave-adblock-default-1p-blocking@1",
    "enable-parallel-downloading@1",
    "enable-quic@1",
    "heuristic-memory-saver-mode@2",    # Memory Saver Aggressive
    "brave-adblock-cookie-list-opt-in@1",
}
existing_flags = set(ls.setdefault("browser", {}).get("enabled_labs_experiments", []))
merged_flags = list(existing_flags | desired_flags)
ls["browser"]["enabled_labs_experiments"] = merged_flags

# ----------------------------------------------------------------
# PERFORMANCE TUNING
# Memory Saver Aggressive + Battery Saver
# ----------------------------------------------------------------
ls.setdefault("performance_tuning", {}).update({
    "high_efficiency_mode": {"aggressiveness": 2, "state": 2},
    "battery_saver_mode":   {"state": 2},
})

# ----------------------------------------------------------------
# P3A — desativa telemetria de produto no Local State também
# ----------------------------------------------------------------
ls["brave"].setdefault("p3a", {})["enabled"] = False

with open(path, "w") as f:
    json.dump(ls, f, separators=(",", ":"))
print("  OK")
PYEOF
    [[ $? -eq 0 ]] && { ok "Local State → ${user}"; ((applied++)) || true; } \
                   || { err "Falha → ${user}"; ((skipped++)) || true; }
  done < <(get_real_users)
  log "Local State: ${applied} OK, ${skipped} ignorados"
}

# =============================================================================
# VERIFY
# =============================================================================
cmd_verify() {
  log "Verificando hardening (v${SCRIPT_VERSION})..."
  echo ""

  # plist
  if [[ -f "$PLIST_PATH" ]] && plutil -lint "$PLIST_PATH" &>/dev/null; then
    ok "plist: OK — ${PLIST_PATH}"
  else
    warn "plist: não encontrado — rode: sudo $0"
  fi
  echo ""

  while IFS= read -r user; do
    local home; home=$(get_home "$user")
    [[ -z "$home" || ! -d "$home" ]] && continue
    local prefs="${home}/${BRAVE_PREFS}"
    local local_state="${home}/${BRAVE_LOCAL}"
    ([[ -f "$prefs" ]] || [[ -f "$local_state" ]]) || continue

    echo "── Usuário: ${user}"

    # Preferences
    if [[ -f "$prefs" ]]; then
      python3 << PYEOF
import json
with open("${prefs}") as f:
    p = json.load(f)
ex = p.get("profile", {}).get("content_settings", {}).get("exceptions", {})
checks = {
    "Shields Aggressive ads":      ex.get("shieldsAds",  {}).get("*,*", {}).get("setting") == 2,
    "Shields Aggressive trackers": ex.get("trackers",    {}).get("*,*", {}).get("setting") == 2,
    "Cosmetic filtering":          bool(ex.get("cosmeticFilteringV2", {}).get("*,*")),
    "Privacy Sandbox off":         not p.get("privacy_sandbox", {}).get("m1", {}).get("topics_enabled", True),
    "Search suggestions off":      not p.get("search", {}).get("suggest_enabled", True),
    "Signin Google off":           not p.get("signin", {}).get("allowed", True),
    "Payments off":                not p.get("payments", {}).get("can_make_payment_enabled", True),
    "WebRTC leak off":             p.get("webrtc", {}).get("ip_handling_policy") == "disable_non_proxied_udp",
    "NTP fundo preto":             p.get("brave", {}).get("new_tab_page", {}).get("background", {}).get("selected_value") == "#000000",
    "NTP só relógio":              p.get("brave", {}).get("new_tab_page", {}).get("show_clock") == True and p.get("brave", {}).get("new_tab_page", {}).get("show_stats") == False,
}
print("  [Preferences]")
for label, ok in checks.items():
    print(f"    {'✓' if ok else '✗'}  {label}")
PYEOF
    fi

    # Local State
    if [[ -f "$local_state" ]]; then
      python3 << PYEOF
import json
with open("${local_state}") as f:
    ls = json.load(f)
ad = ls.get("brave", {}).get("ad_block", {})
subs = ad.get("list_subscriptions", {})
regional = ad.get("regional_filters", {})
flags = set(ls.get("browser", {}).get("enabled_labs_experiments", []))
perf = ls.get("performance_tuning", {})
required_flags = {
    "brave-adblock-default-1p-blocking@1",
    "enable-parallel-downloading@1",
    "enable-quic@1",
    "heuristic-memory-saver-mode@2",
    "brave-adblock-cookie-list-opt-in@1",
}
checks = {
    f"Custom filter lists ({len(subs)})":       len(subs) >= 2,
    f"Regional filters ({len(regional)})":      len(regional) >= 6,
    f"Flags ({len(flags & required_flags)}/5)": required_flags.issubset(flags),
    "Memory Saver Aggressive":                  perf.get("high_efficiency_mode", {}).get("aggressiveness") == 2,
    "Battery Saver":                            perf.get("battery_saver_mode", {}).get("state") == 2,
    "P3A off":                                  not ls.get("brave", {}).get("p3a", {}).get("enabled", True),
}
print("  [Local State]")
for label, ok in checks.items():
    print(f"    {'✓' if ok else '✗'}  {label}")
if subs:
    print("  [Filter lists ativas]")
    for url in subs:
        enabled = subs[url].get("enabled", False)
        print(f"    {'✓' if enabled else '○'}  {url.split('/')[-1]}")
PYEOF
    fi
    echo ""
  done < <(get_real_users)

  log "Verificação completa. Para detalhes: brave://policy | brave://settings/shields"
}

# =============================================================================
# REVERT
# =============================================================================
cmd_revert() {
  log "Revertendo hardening..."
  kill_brave

  [[ -f "$PLIST_PATH" ]] && { rm -f "$PLIST_PATH"; ok "plist removido"; } || warn "plist não encontrado"

  while IFS= read -r user; do
    local home; home=$(get_home "$user")
    [[ -z "$home" || ! -d "$home" ]] && continue

    # Revert Preferences
    local prefs="${home}/${BRAVE_PREFS}"
    if [[ -f "$prefs" ]]; then
      python3 << PYEOF
import json, shutil
path = "${prefs}"
shutil.copy2(path, path + ".bak")
with open(path) as f:
    p = json.load(f)
ex = p.get("profile", {}).get("content_settings", {}).get("exceptions", {})
for k in ["shieldsAds", "trackers", "cosmeticFilteringV2"]:
    ex.pop(k, None)
with open(path, "w") as f:
    json.dump(p, f, separators=(",", ":"))
PYEOF
      ok "Preferences revertido → ${user}"
    fi

    # Revert Local State
    local local_state="${home}/${BRAVE_LOCAL}"
    if [[ -f "$local_state" ]]; then
      python3 << PYEOF
import json, shutil
path = "${local_state}"
shutil.copy2(path, path + ".bak")
with open(path) as f:
    ls = json.load(f)
if "brave" in ls and "ad_block" in ls["brave"]:
    ls["brave"]["ad_block"].pop("list_subscriptions", None)
    ls["brave"]["ad_block"].pop("regional_filters", None)
with open(path, "w") as f:
    json.dump(ls, f, separators=(",", ":"))
PYEOF
      ok "Local State revertido → ${user}"
    fi

  done < <(get_real_users)
  warn "Reinicie o Brave para aplicar."
}

# =============================================================================
# SUMMARY
# =============================================================================
print_summary() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " [plist] SISTEMA"
  echo "   Bloat OFF: Leo AI, Rewards, Wallet, VPN, Tor, News, Talk"
  echo "   Telemetria OFF: P3A, stats ping, Web Discovery, crash"
  echo "   Privacidade: WebRTC, HTTPS-Only, USB, sensores, DNT, GPC"
  echo "   Performance: Memory Saver, Background OFF, NetPred OFF"
  echo ""
  echo " [Preferences] POR USUÁRIO"
  echo "   Shields Aggressive global (ads + trackers + cosmetic)"
  echo "   Privacy Sandbox OFF | Search suggestions OFF"
  echo "   Signin Google OFF | Payments OFF | Autofill cartão OFF"
  echo "   Nova aba: fundo preto + relógio"
  echo ""
  echo " [Local State] POR USUÁRIO"
  echo "   Filter lists: uBlock Filters + Legitimate URL Shortener"
  echo "   Regional filters: 6 listas nativas habilitadas"
  echo "   Flags: 1p-blocking, parallel-dl, QUIC, Memory Saver Agg., cookie-list"
  echo "   Performance: Memory Saver Aggressive + Battery Saver"
  echo "   P3A OFF"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# =============================================================================
# ENTRYPOINT
# =============================================================================
require_root

case "${1:-apply}" in
  --verify)  cmd_verify ;;
  --revert)  cmd_revert ;;
  --prefs)   cmd_prefs;  ok "Preferences aplicado!" ;;
  --local)   cmd_local;  ok "Local State aplicado!" ;;
  --all)
    cmd_apply
    cmd_prefs
    cmd_local
    kill_brave
    echo ""
    ok "Hardening completo! v${SCRIPT_VERSION}"
    print_summary
    ;;
  apply|--apply|"")
    cmd_apply
    kill_brave
    ok "plist aplicado. Para completar: sudo $0 --all"
    print_summary
    ;;
  *)
    echo "Uso: sudo $0 [--all | --prefs | --local | --verify | --revert]"
    exit 1
    ;;
esac
