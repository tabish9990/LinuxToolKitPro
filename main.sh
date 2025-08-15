#!/usr/bin/env bash
# ============================================================================
# Linux Utility Pro — PRO EDITION (single-file, bundled helpers)
# Author/Maintainer: Muhammad Tabish Parray
# Version: 3.0.1
# License: MIT
# ============================================================================
# Highlights
# - Polished TUI with colors, spinners, progress bar
# - Non-interactive subcommands via --run
# - Export reports (txt/json/html)
# - Auto-updater hook (set GITHUB_RAW)
# - Bash/Zsh/Fish completions & manpage
# - .deb / .rpm builders (if dpkg-deb / rpmbuild available)
# - User/System install & uninstall
# - 100% ethical utilities
# ============================================================================
set -Eeuo pipefail
shopt -s extglob

APP_NAME="Linux Utility Pro"
APP_ID="linux-utility-pro"
APP_CMD="lup"
VERSION="3.0.1"

# Paths ----------------------------------------------------------------------
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/${APP_ID}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/${APP_ID}"
LOG_DIR="${DATA_DIR}/logs"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/${APP_ID}"
BACKUP_DIR="${DATA_DIR}/backups"
COMPLETIONS_DIR="${DATA_DIR}/completions"
MAN_DIR="${DATA_DIR}/man"
INSTALL_USER_BIN="$HOME/.local/bin"
INSTALL_SYSTEM_BIN="/usr/local/bin"
SELF_PATH="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"
CONFIG_FILE="${CONFIG_DIR}/config.ini"
LOG_FILE="${LOG_DIR}/lup_$(date +%Y%m%d).log"

# Optional: set to enable self-update ---------------------------------------
# Example: GITHUB_RAW="https://raw.githubusercontent.com/<user>/<repo>/main/lup.sh"
GITHUB_RAW=""

# Colors & styles ------------------------------------------------------------
if [[ -t 1 ]]; then
  NC="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"; ITAL="\033[3m"; ULN="\033[4m"
  BLACK="\033[0;30m"; RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"; BLUE="\033[0;34m"; MAGENTA="\033[0;35m"; CYAN="\033[0;36m"; WHITE="\033[0;37m"
else
  NC=""; BOLD=""; DIM=""; ITAL=""; ULN=""; BLACK=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""; WHITE=""
fi
COLOR_ENABLED=1

cecho(){ local color="$1"; shift; if [[ ${COLOR_ENABLED} -eq 1 ]]; then printf "%b%s%b\n" "${!color}" "$*" "${NC}"; else printf "%s\n" "$*"; fi; }

# Banner ---------------------------------------------------------------------
banner(){
  clear || true
  cat <<'ART' | sed $'s/^/\033[36m/; s/$/\033[0m/'
   _      _                 _   _ _ _         ____             
  | |    (_)               | | (_) | |       |  _ \            
  | |     _ _ __  _   _ ___| |_ _| | |_ ___  | |_) | ___  _ __ 
  | |    | | '_ \| | | / __| __| | | __/ _ \ |  _ < / _ \| '__|
  | |____| | | | | |_| \__ \ |_| | | ||  __/ | |_) | (_) | |   
  |______|_|_| |_|\__,_|___/\__|_|_|\__\___| |____/ \___/|_|   
ART
  cecho YELLOW "${APP_NAME} v${VERSION} — ethical, polished Linux toolkit"
  cecho DIM    "Config: ${CONFIG_FILE}  |  Logs: ${LOG_FILE}"
  printf "\n"
}

# FS init & logging ----------------------------------------------------------
init_fs(){ mkdir -p "${CONFIG_DIR}" "${DATA_DIR}" "${LOG_DIR}" "${CACHE_DIR}" "${BACKUP_DIR}" "${COMPLETIONS_DIR}" "${MAN_DIR}" "${INSTALL_USER_BIN}"; }
log(){ mkdir -p "${LOG_DIR}"; printf "[%s] %s\n" "$(date '+%F %T')" "$*" | tee -a "${LOG_FILE}" >/dev/null; }

# Spinner & progress ---------------------------------------------------------
SPINNER_PID=""
start_spinner(){ local msg="$1"; ( local sp='|/-\\'; local i=0; printf "%s " "$msg"; while :; do i=$(( (i+1) % 4 )); printf "\r%s %s" "$msg" "${sp:$i:1}"; sleep 0.1; done ) & SPINNER_PID=$!; disown || true; }
stop_spinner(){ if [[ -n ${SPINNER_PID} ]] && kill -0 ${SPINNER_PID} 2>/dev/null; then kill ${SPINNER_PID} 2>/dev/null || true; printf "\r%-80s\r" ""; fi; SPINNER_PID=""; }
progress_bar(){ local total=${1:-100}; for ((i=0;i<=total;i++)); do local f=$(( i*40/total )); printf "\r[%-40s] %3d%%" "$(printf '%0.s#' $(seq 1 $f))" "$i"; sleep 0.01; done; printf "\n"; }
trap 'stop_spinner' EXIT

# Config ---------------------------------------------------------------------
load_config(){
  [[ -f ${CONFIG_FILE} ]] || cat >"${CONFIG_FILE}" <<'INI'
# Linux Utility Pro — config
color=1
notify=1
log_level=info
INI
  # shellcheck disable=SC1090
  source <(awk -F= 'NF==2{gsub(/^ +| +$/,"",$1);gsub(/^ +| +$/,"",$2);printf "export CFG_%s=\"%s\"\n",toupper($1),$2}' "${CONFIG_FILE}")
  COLOR_ENABLED=${CFG_COLOR:-1}
}

# Helpers --------------------------------------------------------------------
need(){ command -v "$1" >/dev/null 2>&1; }
require_or_hint(){ local b="$1"; local hint="${2:-}"; if ! need "$b"; then cecho RED "Missing dependency: $b"; [[ -n $hint ]] && cecho YELLOW "$hint"; return 1; fi }
notify(){ local t="$1"; local b="${2:-}"; if [[ ${CFG_NOTIFY:-1} -eq 1 ]] && need notify-send; then notify-send "$t" "$b" || true; fi }

# Utilities ------------------------------------------------------------------
util_check_internet(){ cecho BLUE "Checking internet..."; start_spinner "Ping 1.1.1.1"; local ok=0; if ping -c1 -W1 1.1.1.1 >/dev/null 2>&1; then ok=1; fi; stop_spinner; ((ok)) && cecho GREEN "Online" || cecho RED "Offline"; log "internet ok=${ok}"; }
util_sys_info(){
  cecho BLUE "System Info"; echo "Kernel : $(uname -srmo)";
  if [[ -f /etc/os-release ]]; then . /etc/os-release; echo "OS     : ${NAME} ${VERSION}"; fi
  echo "CPU    : $(awk -F: '/model name/{print $2;exit}' /proc/cpuinfo | sed 's/^ //')"
  echo "Memory : $(free -h | awk '/Mem:/{print $2" total, " $3" used, " $4" free"}')"
  echo "Uptime : $(uptime -p 2>/dev/null || true)"
  echo "Disk   :"; df -hT -x tmpfs -x devtmpfs | awk 'NR==1||$6>80{printf "  %-20s %-6s %-6s %-6s %-s\n", $7,$3,$4,$6,$2}'
}
util_disk_report(){ cecho BLUE "Filesystem usage"; df -hT -x tmpfs -x devtmpfs | awk 'NR==1{print;next}{printf "%-20s %-8s %-8s %-6s %-s\n", $7,$3,$4,$6,$2}' }
util_mem_top(){ cecho BLUE "Top 10 memory processes"; ps axo pid,comm,%mem,%cpu --sort=-%mem | head -n 11 | awk 'NR==1{printf "%-8s %-22s %-6s %-6s\n",$1,$2,$3,$4;next}{printf "%-8s %-22s %-6s %-6s\n",$1,$2,$3,$4}' ; }
util_cpu_monitor(){ cecho BLUE "CPU Live (q to quit)"; if need top; then top -d 1; else vmstat 1; fi }
util_wifi_signal(){ if need nmcli; then nmcli -f SSID,CHAN,SIGNAL,SECURITY dev wifi list; elif need iwconfig; then iwconfig 2>/dev/null | sed 's/^/  /'; else cecho YELLOW "Install nmcli (NetworkManager) or iwconfig (wireless-tools)"; fi }
util_net_info(){ cecho BLUE "Interfaces"; (need ip && ip -brief addr) || ip addr; cecho BLUE "Listening Ports"; (need ss && ss -tulpen | head -n 25) || cecho YELLOW "ss not available"; }
util_url_health(){ read -rp "URL (https://example.com): " url; [[ -z ${url} ]] && return; if need curl; then cecho BLUE "HEAD ${url}"; curl -Is --max-time 7 "$url" | head -n 1; else cecho RED "curl missing"; fi }
util_find_files(){ read -rp "Directory [.] : " dir; dir=${dir:-.}; read -rp "Pattern [*.log] : " pat; pat=${pat:-*.log}; cecho BLUE "Searching..."; find "$dir" -type f -name "$pat" -printf "%p\t%k KB\n" 2>/dev/null | head -n 100; }
util_checksum(){ read -rp "File: " fp; [[ -f $fp ]] || { cecho RED "Not a file"; return; }; cecho BLUE "SHA256:"; sha256sum "$fp" || true }
util_temp_sensors(){ if need sensors; then sensors | sed 's/^/  /'; else cecho YELLOW "lm-sensors not installed"; fi }
util_battery(){ if need upower; then upower -e | grep BAT | while read -r b; do echo "- ${b}"; upower -i "$b" | awk '/state|percentage|time to/'; done; else cecho YELLOW "Install upower for battery info"; fi }
util_pkg_health(){ if need apt; then sudo apt update && sudo apt -y -o Dpkg::Use-Pty=0 check || true; elif need dnf; then sudo dnf check-update || true; elif need pacman; then sudo pacman -Sy --noconfirm || true; else cecho YELLOW "Unknown package manager"; fi }
util_git_helper(){ if [[ -d .git ]]; then git status; git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's/^/Branch: /'; git log --oneline -5; else cecho YELLOW "Not a git repo"; fi }
util_kill_process(){ ps axo pid,comm,%mem,%cpu --sort=-%cpu | head -n 20; read -rp "PID to kill (blank to cancel): " pid; [[ -z ${pid} ]] && return; read -rp "Send SIGTERM (default) or SIGKILL? [TERM/KILL]: " sig; sig=${sig^^}; sig=${sig:-TERM}; kill -s "$sig" "$pid" && cecho GREEN "Signal $sig sent." || cecho RED "Failed"; }
util_shred(){ read -rp "File to shred (irreversible): " f; [[ -f $f ]] || { cecho RED "No such file"; return; }; read -rp "Type 'YES' to confirm: " c; [[ $c == "YES" ]] || { cecho YELLOW "Cancelled"; return; }; (need shred && shred -u -v "$f") || { cecho YELLOW "shred missing; using rm -P"; rm -P "$f" 2>/dev/null || rm -f "$f"; }; cecho GREEN "Done." }
util_backup(){ read -rp "File to back up: " src; [[ -f $src ]] || { cecho RED "No such file"; return; }; mkdir -p "$BACKUP_DIR"; local base out; base=$(basename "$src"); out="${BACKUP_DIR}/${base}.bak.$(date +%Y%m%d_%H%M%S)"; cp -a "$src" "$out" && cecho GREEN "Saved: $out"; }
util_cleanup_cache(){ cecho BLUE "Cache: ${CACHE_DIR}"; du -sh "${CACHE_DIR}" 2>/dev/null || true; read -rp "Delete cache? [y/N]: " a; [[ ${a,,} == y* ]] && rm -rf "${CACHE_DIR}" && cecho GREEN "Cleared"; }

# Report collectors -----------------------------------------------------------
collect_report_plain(){
  COLOR_ENABLED=0
  util_sys_info
  echo
  echo "Processes (top 15 by mem):"
  ps axo pid,comm,%mem,%cpu --sort=-%mem | head -n 15
  echo
  echo "Network:"
  if need ip; then ip -brief addr; else ip addr; fi
}
collect_report_json(){
  local os k cpu mem up
  os=$(source /etc/os-release 2>/dev/null; echo "${NAME:-Unknown} ${VERSION:-}")
  k=$(uname -srmo)
  cpu=$(awk -F: '/model name/{print $2;exit}' /proc/cpuinfo | sed 's/^ //')
  mem=$(free -h | awk '/Mem:/{print $2" total, " $3" used, " $4" free"}')
  up=$(uptime -p 2>/dev/null || echo "")
  cat <<JSON
{
  "app": "${APP_NAME}",
  "version": "${VERSION}",
  "system": {"os": "${os}", "kernel": "${k}", "cpu": "${cpu}", "memory": "${mem}", "uptime": "${up}"}
}
JSON
}
collect_report_html(){
  local sys top net
  sys=$(COLOR_ENABLED=0; util_sys_info 2>&1)
  top=$(ps axo pid,comm,%mem,%cpu --sort=-%mem | head -n 15)
  if need ip; then net=$(ip -brief addr); else net=$(ip addr); fi
  cat <<HTML
<!doctype html><html><head><meta charset="utf-8"><title>${APP_NAME} Report</title>
<style>body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Arial,sans-serif;padding:24px;background:#0f172a;color:#e2e8f0} h1{color:#93c5fd} pre{background:#111827;padding:12px;border-radius:10px;overflow:auto} .card{background:#0b1220;border:1px solid #1f2937;border-radius:16px;padding:16px;margin:12px 0;box-shadow:0 8px 24px rgba(0,0,0,.35)}</style>
</head><body>
<h1>${APP_NAME} — Report</h1>
<div class="card"><h3>System</h3><pre>${sys}</pre></div>
<div class="card"><h3>Top Processes</h3><pre>${top}</pre></div>
<div class="card"><h3>Network</h3><pre>${net}</pre></div>
<footer><small>Generated: $(date)</small></footer>
</body></html>
HTML
}
export_report(){
  local fmt="${1:-txt}"; local out dir="${DATA_DIR}/reports"; mkdir -p "$dir"
  case "${fmt}" in
    txt)  out="${dir}/report_$(date +%Y%m%d_%H%M%S).txt";  collect_report_plain >"$out" ;;
    json) out="${dir}/report_$(date +%Y%m%d_%H%M%S).json"; collect_report_json  >"$out" ;;
    html) out="${dir}/report_$(date +%Y%m%d_%H%M%S).html"; collect_report_html >"$out" ;;
    *) cecho RED "Unknown format: ${fmt}"; return 1 ;;
  esac
  cecho GREEN "Saved ${out}"; echo "$out"
}

# Self-update ----------------------------------------------------------------
self_update(){
  if [[ -z ${GITHUB_RAW} ]]; then cecho YELLOW "GITHUB_RAW not set. Edit script to enable updater."; return 1; fi
  require_or_hint curl "Install curl." || return 1
  local tmp="${CACHE_DIR}/lup_update.sh"; mkdir -p "${CACHE_DIR}"
  start_spinner "Fetching latest..."; curl -fsSL "${GITHUB_RAW}" -o "$tmp" || { stop_spinner; cecho RED "Download failed"; return 1; }
  stop_spinner
  if grep -q "APP_NAME" "$tmp"; then chmod +x "$tmp"; cp "$tmp" "$SELF_PATH"; cecho GREEN "Updated ${APP_CMD} from ${GITHUB_RAW}"; else cecho RED "Downloaded file doesn't look like ${APP_CMD}"; return 1; fi
}

# Completions ----------------------------------------------------------------
completion_bash(){ cat <<'BASH'
# bash completion for lup
_lup(){
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="help version net sys disk mem cpu wifi git pkg kill shred sum temp bat find url backup clean export update --no-color --run --install --uninstall --install-system --uninstall-system --format"
  if [[ ${cur} == -* ]]; then COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) ); return 0; fi
  case "${prev}" in
    --run) COMPREPLY=( $(compgen -W "net sys disk mem cpu wifi git pkg kill shred sum temp bat find url backup clean export update" -- ${cur}) ); return 0 ;;
    export|--format) COMPREPLY=( $(compgen -W "txt json html" -- ${cur}) ); return 0 ;;
  esac
  COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
}
complete -F _lup lup
BASH
}
completion_zsh(){ cat <<'ZSH'
#compdef lup
_arguments \
  '1: :->sub' \
  '*:: :->args'
case $state in
  sub)
    _values 'subcommand' net sys disk mem cpu wifi git pkg kill shred sum temp bat find url backup clean export update ;;
  args)
    _values 'options' --no-color --install --uninstall --install-system --uninstall-system --run --format ;;
endcase
ZSH
}
completion_fish(){ cat <<'FISH'
complete -c lup -f -a "net sys disk mem cpu wifi git pkg kill shred sum temp bat find url backup clean export update"
complete -c lup -l run -x -a "net sys disk mem cpu wifi git pkg kill shred sum temp bat find url backup clean export update"
complete -c lup -l format -x -a "txt json html"
FISH
}
install_completions(){ mkdir -p "${COMPLETIONS_DIR}"; completion_bash >"${COMPLETIONS_DIR}/lup.bash"; completion_zsh >"${COMPLETIONS_DIR}/_lup"; completion_fish >"${COMPLETIONS_DIR}/lup.fish"; cecho GREEN "Completions written to: ${COMPLETIONS_DIR}"; }

# Man page -------------------------------------------------------------------
make_man(){
  mkdir -p "${MAN_DIR}"
  cat >"${MAN_DIR}/${APP_CMD}.1" <<'MAN'
." Manpage for lup
.TH LUP 1 "" "Linux Utility Pro" "User Commands"
.SH NAME
lup \- Linux Utility Pro
.SH SYNOPSIS
.B lup
[--run CMD] [--format FMT] [--no-color] [--install] [--uninstall]
.SH DESCRIPTION
A polished, ethical Linux toolkit.
.SH COMMANDS
net, sys, disk, mem, cpu, wifi, git, pkg, kill, shred, sum, temp, bat, find, url, backup, clean, export, update
.SH AUTHOR
Muhammad Tabish Parray
MAN
  cecho GREEN "Manpage created at ${MAN_DIR}/${APP_CMD}.1"
}

# Packaging ------------------------------------------------------------------
build_deb(){
  require_or_hint dpkg-deb "apt install dpkg-dev" || return 1
  local build="${CACHE_DIR}/deb_build"; rm -rf "$build"; mkdir -p "$build/DEBIAN" "$build/usr/bin" "$build/usr/share/man/man1" "$build/usr/share/bash-completion/completions" "$build/usr/share/zsh/site-functions" "$build/usr/share/fish/vendor_completions.d"
  install -m 0755 "$SELF_PATH" "$build/usr/bin/${APP_CMD}"
  make_man; gzip -c "${MAN_DIR}/${APP_CMD}.1" >"$build/usr/share/man/man1/${APP_CMD}.1.gz"
  completion_bash >"$build/usr/share/bash-completion/completions/${APP_CMD}"
  completion_zsh  >"$build/usr/share/zsh/site-functions/_${APP_CMD}"
  completion_fish >"$build/usr/share/fish/vendor_completions.d/${APP_CMD}.fish"
  cat >"$build/DEBIAN/control" <<CTRL
Package: ${APP_ID}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: all
Maintainer: Muhammad Tabish Parray
Description: ${APP_NAME} — Pro Edition (single-file)
CTRL
  ( cd "${CACHE_DIR}" && dpkg-deb --build deb_build ${APP_ID}_${VERSION}_all.deb )
  cecho GREEN "Built: ${CACHE_DIR}/${APP_ID}_${VERSION}_all.deb"
}

build_rpm(){
  require_or_hint rpmbuild "dnf install rpm-build (or apt install rpm)" || return 1
  local top="${CACHE_DIR}/rpmbuild"; rm -rf "$top"; mkdir -p "$top/BUILD" "$top/RPMS" "$top/SOURCES" "$top/SPECS" "$top/SRPMS"
  local spec="$top/SPECS/${APP_ID}.spec"
  local manfile
  make_man; manfile="${MAN_DIR}/${APP_CMD}.1"
  completion_bash >"${CACHE_DIR}/bash_comp"; completion_zsh >"${CACHE_DIR}/_lup"; completion_fish >"${CACHE_DIR}/lup.fish"
  cat >"$spec" <<SPEC
Name:           ${APP_ID}
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        ${APP_NAME} — Pro Edition
License:        MIT
BuildArch:      noarch
%description
${APP_NAME} — Pro Edition single-file tool.
%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 ${SELF_PATH} %{buildroot}/usr/bin/${APP_CMD}
mkdir -p %{buildroot}/usr/share/man/man1
install -m 0644 ${manfile} %{buildroot}/usr/share/man/man1/${APP_CMD}.1
mkdir -p %{buildroot}/usr/share/bash-completion/completions
cat ${CACHE_DIR}/bash_comp > %{buildroot}/usr/share/bash-completion/completions/${APP_CMD}
mkdir -p %{buildroot}/usr/share/zsh/site-functions
cat ${CACHE_DIR}/_lup > %{buildroot}/usr/share/zsh/site-functions/_${APP_CMD}
mkdir -p %{buildroot}/usr/share/fish/vendor_completions.d
cat ${CACHE_DIR}/lup.fish > %{buildroot}/usr/share/fish/vendor_completions.d/${APP_CMD}.fish
%files
/usr/bin/${APP_CMD}
/usr/share/man/man1/${APP_CMD}.1
/usr/share/bash-completion/completions/${APP_CMD}
/usr/share/zsh/site-functions/_${APP_CMD}
/usr/share/fish/vendor_completions.d/${APP_CMD}.fish
%changelog
* $(date "+%a %b %d %Y") M T Parray - ${VERSION}-1
- Initial RPM
SPEC
  rpmbuild --define "_topdir ${top}" -bb "$spec" || { cecho RED "rpmbuild failed"; return 1; }
  find "$top/RPMS" -type f -name "*.rpm" -print -exec bash -c 'echo' \; 2>/dev/null | while read -r f; do cecho GREEN "Built: $f"; done
}

# Installers -----------------------------------------------------------------
install_user(){ install -m 0755 "$SELF_PATH" "${INSTALL_USER_BIN}/${APP_CMD}"; cecho GREEN "Installed: ${INSTALL_USER_BIN}/${APP_CMD}"; }
install_system(){ sudo install -m 0755 "$SELF_PATH" "${INSTALL_SYSTEM_BIN}/${APP_CMD}"; cecho GREEN "Installed: ${INSTALL_SYSTEM_BIN}/${APP_CMD}"; }
uninstall_user(){ rm -f "${INSTALL_USER_BIN}/${APP_CMD}" && cecho GREEN "Removed ${INSTALL_USER_BIN}/${APP_CMD}" || cecho YELLOW "Nothing to remove"; }
uninstall_system(){ sudo rm -f "${INSTALL_SYSTEM_BIN}/${APP_CMD}" && cecho GREEN "Removed ${INSTALL_SYSTEM_BIN}/${APP_CMD}" || cecho YELLOW "Nothing to remove"; }

# Help -----------------------------------------------------------------------
show_help(){ cat <<EOF
${APP_NAME} v${VERSION}
Usage: ${APP_CMD} [options]

Options:
  -h, --help            Show help
  -v, --version         Show version
  --no-color            Disable colored output
  --run CMD             Run a command non-interactively
  --format FMT          Used with 'export' (txt|json|html)
  --install             Install to ${INSTALL_USER_BIN}
  --install-system      Install to ${INSTALL_SYSTEM_BIN} (sudo)
  --uninstall           Remove from ${INSTALL_USER_BIN}
  --uninstall-system    Remove from ${INSTALL_SYSTEM_BIN} (sudo)
  --completions         Generate shell completions
  --man                 Generate manpage
  --build-deb           Build .deb package (dpkg-deb)
  --build-rpm           Build .rpm package (rpmbuild)
  --update              Self-update (needs GITHUB_RAW)

Commands (for --run):
  net sys disk mem cpu wifi git pkg kill shred sum temp bat find url backup clean export update
EOF
}

# Menu -----------------------------------------------------------------------
menu(){
  banner
  cecho YELLOW "Select an option:"
  cat <<M
  1) Check Internet        9) Temperature Sensors
  2) System Info          10) Battery Status
  3) Disk Usage           11) Cleanup Cache
  4) Top Memory Procs     12) Backup a File
  5) CPU Monitor          13) Export Report (choose)
  6) Wi‑Fi Signal         14) Generate Completions
  7) Network Info         15) Build .deb / .rpm
  8) URL Health Check     16) Self‑Update
  i) Install (user)       I) Install (system)
  u) Uninstall (user)     U) Uninstall (system)
  q) Quit
M
  read -rp "Enter choice: " c
  case "$c" in
    1) util_check_internet ;;
    2) util_sys_info ;;
    3) util_disk_report ;;
    4) util_mem_top ;;
    5) util_cpu_monitor ;;
    6) util_wifi_signal ;;
    7) util_net_info ;;
    8) util_url_health ;;
    9) util_temp_sensors ;;
   10) util_battery ;;
   11) util_cleanup_cache ;;
   12) util_backup ;;
   13) read -rp "Format (txt/json/html): " f; export_report "$f" ;;
   14) install_completions ;;
   15) read -rp "Build (deb/rpm): " p; [[ $p == deb ]] && build_deb || [[ $p == rpm ]] && build_rpm || cecho YELLOW "Skipped" ;;
   16) self_update ;;
    i) install_user ;;
    I) install_system ;;
    u) uninstall_user ;;
    U) uninstall_system ;;
    q|Q) exit 0 ;;
    *) cecho RED "Invalid choice" ;;
  esac
  read -rp "Enter to continue..." _
  menu
}

# CLI ------------------------------------------------------------------------
main(){
  init_fs; load_config
  local run_cmd="" fmt="" do_menu=1
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help; return 0 ;;
      -v|--version) echo "${APP_NAME} ${VERSION}"; return 0 ;;
      --no-color) COLOR_ENABLED=0; shift; continue ;;
      --run) run_cmd="${2:-}"; do_menu=0; shift 2; continue ;;
      --format) fmt="${2:-}"; shift 2; continue ;;
      --install) install_user; return 0 ;;
      --install-system) install_system; return 0 ;;
      --uninstall) uninstall_user; return 0 ;;
      --uninstall-system) uninstall_system; return 0 ;;
      --completions) install_completions; return 0 ;;
      --man) make_man; return 0 ;;
      --build-deb) build_deb; return 0 ;;
      --build-rpm) build_rpm; return 0 ;;
      --update) self_update; return 0 ;;
      *) cecho RED "Unknown option: $1"; show_help; return 1 ;;
    esac
  done

 if [ -n "$run_cmd" ]; then
    case "$run_cmd" in
        net) util_check_internet ;;
        sys) util_sys_info ;;
        disk) util_disk_report ;;
        mem) util_mem_top ;;
        cpu) util_cpu_monitor ;;
        wifi) util_wifi_signal ;;
        git) util_git_helper ;;
        pkg) util_pkg_health ;;
        kill) util_kill_process ;;
        shred) util_shred ;;
        checksum) util_checksum ;;
        temp) util_temp_sensors ;;
        bat) util_battery ;;
        find) util_find_files ;;
        url) util_url_health ;;
        backup) util_backup ;;
        clean) util_cleanup_cache ;;
        export) export_report "${fmt:=txt}" ;;
        update) self_update ;;
        *) echo RED "Unknown run command: $run_cmd"; return 1 ;;
    esac
    return 0
fi

menu
main "$@"
