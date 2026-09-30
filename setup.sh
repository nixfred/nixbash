#!/usr/bin/env bash
# NixBash Interactive Setup - Full server provisioning
# https://github.com/nixfred/nixbash
#
# Usage: curl -sL https://raw.githubusercontent.com/nixfred/nixbash/main/setup.sh | sudo bash
#
# Interactive first-boot setup for fresh Linux servers.
# For non-interactive shell-only install, use install.sh instead.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

info()  { echo -e "${CYAN}[NixSetup]${RESET} $*"; }
ok()    { echo -e "${GREEN}[NixSetup]${RESET} ✅ $*"; }
warn()  { echo -e "${YELLOW}[NixSetup]${RESET} ⚠️  $*"; }
fail()  { echo -e "${RED}[NixSetup]${RESET} ❌ $*"; exit 1; }
step()  { echo -e "\n${BOLD}${CYAN}━━ Step $1/$TOTAL_STEPS: $2 ━━${RESET}"; }

ask() {
    local prompt="$1" default="${2:-}" var
    if [ -n "$default" ]; then
        read -rp "$(echo -e "${CYAN}[?]${RESET} ${prompt} [${default}]: ")" var < /dev/tty
        echo "${var:-$default}"
    else
        read -rp "$(echo -e "${CYAN}[?]${RESET} ${prompt}: ")" var < /dev/tty
        echo "$var"
    fi
}

ask_yn() {
    local prompt="$1" default="${2:-y}" answer
    read -rp "$(echo -e "${CYAN}[?]${RESET} ${prompt} [${default}]: ")" answer < /dev/tty
    answer="${answer:-$default}"
    if [[ "$answer" =~ ^[Yy] ]]; then
        return 0
    else
        return 1
    fi
}

ask_secret() {
    local prompt="$1" var=""
    # Print prompt to tty, read silently from tty
    printf "${CYAN}[?]${RESET} %s: " "$prompt" > /dev/tty
    # Disable echo, read, restore echo
    stty -echo < /dev/tty 2>/dev/null || true
    IFS= read -r var < /dev/tty
    stty echo < /dev/tty 2>/dev/null || true
    echo "" > /dev/tty
    printf '%s' "$var"
}

# ── Require root ───────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    fail "This script must be run as root (sudo bash setup.sh)"
fi

# ── Require apt-based distro for full provisioning ─────────────────
if ! command -v apt-get >/dev/null 2>&1; then
    fail "setup.sh currently supports apt-based systems only. On Fedora/Arch, use install.sh for the shell environment and provision the rest manually."
fi

START_TIME=$(date +%s)

echo ""
echo -e "${BOLD}${CYAN}⚡ NixBash Interactive Setup${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  Full server provisioning for fresh apt-based Linux boxes"
echo -e "  ${DIM}Running as root on $(hostname) — $(date '+%Y-%m-%d %H:%M:%S %Z')${RESET}"
echo -e "  For shell-only install, use ${BOLD}install.sh${RESET} instead"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# ══════════════════════════════════════════════════════════════════
# GATHER CHOICES
# ══════════════════════════════════════════════════════════════════

# ── User Setup ────────────────────────────────────────────────────
echo -e "${BOLD}── User Setup ──${RESET}"
CREATE_USER="n"
SET_PASS="n"
EXISTING_USER=""
# Rerun support: when launched with sudo from an existing account, set that
# account up instead of asking to create one.
INVOKER="${SUDO_USER:-}"
if [ -n "$INVOKER" ] && [ "$INVOKER" != "root" ] && id "$INVOKER" &>/dev/null \
   && ask_yn "Set up the current user '${INVOKER}' (already exists)?" "y"; then
    EXISTING_USER="$INVOKER"
    ok "Setting up existing user '${INVOKER}' -- password unchanged"
elif ask_yn "Create (or set up) a sudo user?"; then
    CREATE_USER="y"
    # FIX: validate username BEFORE password loop, reject dangerous characters
    while true; do
        NEW_USER=$(ask "Username")
        if [ -z "$NEW_USER" ]; then
            warn "Username cannot be empty -- try again"
        elif [[ "$NEW_USER" =~ ^- ]]; then
            warn "Username cannot start with a dash -- try again"
        elif ! [[ "$NEW_USER" =~ ^[a-z_][a-z0-9._-]*$ ]]; then
            warn "Username must start with a lowercase letter or _, then lowercase letters, numbers, . _ - -- try again"
        elif [ "${#NEW_USER}" -gt 32 ]; then
            warn "Username cannot exceed 32 characters -- try again"
        else
            break
        fi
    done
    SET_PASS="y"
    if id "$NEW_USER" &>/dev/null; then
        info "User '${NEW_USER}' already exists -- it will be set up, not recreated"
        ask_yn "Reset ${NEW_USER}'s password?" "n" || SET_PASS="n"
    fi
    while [ "$SET_PASS" = "y" ]; do
        NEW_PASS=$(ask_secret "Password for ${NEW_USER}")
        NEW_PASS2=$(ask_secret "Confirm password")
        if [ -z "$NEW_PASS" ]; then
            warn "Password cannot be empty -- try again"
        elif [ "$NEW_PASS" != "$NEW_PASS2" ]; then
            warn "Passwords do not match -- try again"
        else
            ok "Password confirmed"
            break
        fi
    done
fi

# ── Hostname ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── System ──${RESET}"
CURRENT_HOST=$(hostname)
while true; do
    NEW_HOST=$(ask "Hostname" "$CURRENT_HOST")
    [[ "$NEW_HOST" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]] && break
    warn "Hostname: letters, numbers and hyphens only (no dots/spaces, not starting or ending with -) -- try again"
done

# ── Timezone ──────────────────────────────────────────────────────
CURRENT_TZ=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "UTC")
# Numbered menu so only a real zoneinfo name can be chosen (a typed "CST"
# once left a box on UTC).
TZ_CHOICES=(America/New_York America/Chicago America/Denver America/Phoenix
            America/Los_Angeles America/Anchorage Pacific/Honolulu UTC
            Europe/London Europe/Berlin Asia/Tokyo Australia/Sydney)
echo -e "  Timezone (current: ${BOLD}${CURRENT_TZ}${RESET})"
echo "   0) Keep current (${CURRENT_TZ})"
for i in "${!TZ_CHOICES[@]}"; do
    printf '  %2d) %s\n' "$((i + 1))" "${TZ_CHOICES[$i]}"
done
echo "  99) Other (type a Region/City name)"
while true; do
    TZ_PICK=$(ask "Choose timezone" "0")
    if [ "$TZ_PICK" = "0" ]; then
        NEW_TZ="$CURRENT_TZ"
    elif [[ "$TZ_PICK" =~ ^[0-9]+$ ]] && [ "$TZ_PICK" -ge 1 ] && [ "$TZ_PICK" -le "${#TZ_CHOICES[@]}" ]; then
        NEW_TZ="${TZ_CHOICES[$((TZ_PICK - 1))]}"
    elif [ "$TZ_PICK" = "99" ]; then
        NEW_TZ=$(ask "Timezone (e.g. America/Chicago, see: timedatectl list-timezones)")
    else
        warn "Pick a number from the list -- try again"
        continue
    fi
    if [[ "$NEW_TZ" != *..* ]] && [ -f "/usr/share/zoneinfo/${NEW_TZ}" ]; then
        ok "Timezone: ${NEW_TZ}"
        break
    fi
    warn "Unknown timezone '${NEW_TZ}' -- try again"
done

# ── SSH Key ───────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── SSH ──${RESET}"
SSH_METHOD="none"
GH_USER=""
SSH_KEY=""
if ask_yn "Import SSH key?"; then
    echo -e "  ${CYAN}1)${RESET} From GitHub username"
    echo -e "  ${CYAN}2)${RESET} Paste public key manually"
    SSH_CHOICE=$(ask "Choose" "1")
    if [ "$SSH_CHOICE" = "1" ]; then
        SSH_METHOD="github"
        while true; do
            GH_USER=$(ask "GitHub username")
            [[ "$GH_USER" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,38})$ ]] && break
            warn "Not a valid GitHub username -- try again"
        done
    else
        SSH_METHOD="paste"
        SSH_KEY=$(ask "Paste your public key")
    fi
fi

# ── Optional Components ──────────────────────────────────────────
echo ""
echo -e "${BOLD}── Components ──${RESET}"
if ask_yn "Install Docker?" "y"; then INSTALL_DOCKER="y"; else INSTALL_DOCKER="n"; fi
if ask_yn "Install Claude Code?" "y"; then INSTALL_CLAUDE="y"; else INSTALL_CLAUDE="n"; fi
if ask_yn "Install Tailscale?" "y"; then INSTALL_TAILSCALE="y"; else INSTALL_TAILSCALE="n"; fi

TS_KEY=""
if [ "$INSTALL_TAILSCALE" = "y" ]; then
    TS_KEY=$(ask "Tailscale auth key (blank = authenticate manually)")
fi

if ask_yn "Install essential tools (20 packages: git, vim, tmux, nmap, rsync, etc.)?" "y"; then INSTALL_ESSENTIALS="y"; else INSTALL_ESSENTIALS="n"; fi
if ask_yn "Install extras (monitoring, fun, security — 30+ more packages)?" "n"; then INSTALL_EXTRAS="y"; else INSTALL_EXTRAS="n"; fi

echo ""
echo -e "${BOLD}── Security & System ──${RESET}"
if ask_yn "Harden: UFW firewall (SSH only) + key-only SSH (only if a key is installed)?" "y"; then HARDEN="y"; else HARDEN="n"; fi
if ask_yn "System basics: swap file if none, en_US.UTF-8 locale, clock sync?" "y"; then SYS_BASICS="y"; else SYS_BASICS="n"; fi

GIT_NAME=""; GIT_EMAIL=""
GIT_NAME=$(ask "Git user.name (blank = skip)")
[ -n "$GIT_NAME" ] && GIT_EMAIL=$(ask "Git user.email")

# ── Confirmation ──────────────────────────────────────────────────
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  Setup Summary${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
[ "$CREATE_USER" = "y" ] && echo -e "  User:       ${GREEN}${NEW_USER}${RESET} (sudo, NOPASSWD)"
[ -n "$EXISTING_USER" ] && echo -e "  User:       ${GREEN}${EXISTING_USER}${RESET} (existing, set up in place)"
echo -e "  Hostname:   ${GREEN}${NEW_HOST}${RESET}"
echo -e "  Timezone:   ${GREEN}${NEW_TZ}${RESET}"
[ "$SSH_METHOD" = "github" ] && echo -e "  SSH Key:    ${GREEN}from github.com/${GH_USER}${RESET}"
[ "$SSH_METHOD" = "paste" ] && echo -e "  SSH Key:    ${GREEN}manual paste${RESET}"
echo -e "  Docker:     $([ "$INSTALL_DOCKER" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
echo -e "  Claude:     $([ "$INSTALL_CLAUDE" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
echo -e "  Tailscale:  $([ "$INSTALL_TAILSCALE" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
echo -e "  Essentials: $([ "$INSTALL_ESSENTIALS" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
echo -e "  Extras:     $([ "$INSTALL_EXTRAS" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
echo -e "  Hardening:  $([ "$HARDEN" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
echo -e "  Sys basics: $([ "$SYS_BASICS" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
[ -n "$GIT_NAME" ] && echo -e "  Git:        ${GREEN}${GIT_NAME} <${GIT_EMAIL}>${RESET}"
echo -e "  NixBash:    ${GREEN}yes (always)${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if ! ask_yn "Proceed with setup?"; then
    warn "Aborted by user."
    exit 0
fi

# ══════════════════════════════════════════════════════════════════
# EXECUTION — verbose narrated output
# ══════════════════════════════════════════════════════════════════

# Calculate total steps dynamically
TOTAL_STEPS=5  # update, hostname/tz, user env, nixbash, cleanup — always present
[ "$HARDEN" = "y" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$SYS_BASICS" = "y" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$CREATE_USER" = "y" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$SSH_METHOD" != "none" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$INSTALL_ESSENTIALS" = "y" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$INSTALL_EXTRAS" = "y" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$INSTALL_DOCKER" = "y" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$INSTALL_TAILSCALE" = "y" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$INSTALL_CLAUDE" = "y" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))

LOG_FILE=/var/log/nixbash-setup.log
touch "$LOG_FILE" && chmod 600 "$LOG_FILE"
echo "===== NixBash setup $(date '+%F %T %Z') =====" >> "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'warn "Setup stopped unexpectedly at setup.sh line ${LINENO} -- full log: ${LOG_FILE}"' ERR

CURRENT_STEP=0
next_step() { CURRENT_STEP=$((CURRENT_STEP + 1)); step "$CURRENT_STEP" "$1"; }

echo ""
echo -e "${BOLD}${GREEN}🚀 Starting setup — ${TOTAL_STEPS} steps to go...${RESET}"

# ── System update ─────────────────────────────────────────────────
next_step "System Update"
# FIX: pipefail + apt | tail kills script if apt fails. Use subshell to isolate.
# FIX: DEBIAN_FRONTEND prevents dpkg interactive config prompts from hanging.
info "Updating package lists..."
(apt-get update 2>&1 || true) | tail -3
info "Upgrading installed packages..."
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confold" upgrade -y 2>&1 | tail -5 || true
ok "System packages are up to date"

# ── Hostname & Timezone ──────────────────────────────────────────
next_step "Hostname & Timezone"
if [ "$NEW_HOST" != "$CURRENT_HOST" ]; then
    info "Changing hostname: ${CURRENT_HOST} → ${NEW_HOST}"
    hostnamectl set-hostname "$NEW_HOST" 2>/dev/null || { echo "$NEW_HOST" > /etc/hostname; hostname "$NEW_HOST" 2>/dev/null || true; }
    # FIX: append 127.0.1.1 line if not present, otherwise update it
    if grep -q "127.0.1.1" /etc/hosts 2>/dev/null; then
        sed -i "s/127.0.1.1.*/127.0.1.1\t${NEW_HOST}/" /etc/hosts 2>/dev/null || true
    else
        printf '127.0.1.1\t%s\n' "$NEW_HOST" >> /etc/hosts
    fi
    ok "Hostname set to ${NEW_HOST}"
else
    info "Hostname unchanged: ${CURRENT_HOST}"
fi

info "Setting timezone to ${NEW_TZ}..."
timedatectl set-timezone "$NEW_TZ" 2>/dev/null || ln -sf "/usr/share/zoneinfo/${NEW_TZ}" /etc/localtime
ok "Timezone set to ${NEW_TZ} — current time: $(date '+%H:%M:%S %Z')"

# ── Create user ───────────────────────────────────────────────────
if [ "$CREATE_USER" = "y" ]; then
    next_step "Create User"
    # Ensure sudo is installed (minimal containers may not have it)
    if ! command -v sudo >/dev/null 2>&1; then
        info "Installing sudo..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y sudo 2>&1 | grep -E "^(Setting up|is already)" || true
        ok "sudo installed"
    fi
    if id "$NEW_USER" &>/dev/null; then
        info "User '${NEW_USER}' already exists -- setting it up"
        usermod -aG sudo "$NEW_USER"
        if [ "$SET_PASS" = "y" ]; then
            # printf is a bash builtin -- password never appears in ps/proc
            printf '%s:%s\n' "$NEW_USER" "$NEW_PASS" | chpasswd
            ok "Password updated"
        fi
    else
        info "Creating user '${NEW_USER}' with home directory and bash shell..."
        groupadd -f sudo
        useradd -m -s /bin/bash -G sudo "$NEW_USER"
        # FIX: printf is a bash builtin -- no subprocess, so password never appears in ps/proc
printf '%s:%s\n' "$NEW_USER" "$NEW_PASS" | chpasswd
        ok "User '${NEW_USER}' created — home dir: /home/${NEW_USER}"
    fi
    info "Granting passwordless sudo..."
    mkdir -p /etc/sudoers.d
    echo "${NEW_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${NEW_USER}"
    chmod 440 "/etc/sudoers.d/${NEW_USER}"
    ok "Sudo NOPASSWD configured — ${NEW_USER} can run any command without password"
    TARGET_USER="$NEW_USER"
    # FIX: eval with user input is code injection -- use getent to safely resolve home
TARGET_HOME=$(getent passwd "$NEW_USER" | cut -d: -f6 || true)
[ -z "$TARGET_HOME" ] && TARGET_HOME="/home/${NEW_USER}"
else
    TARGET_USER="${EXISTING_USER:-${SUDO_USER:-$(logname 2>/dev/null || echo root)}}"
    # FIX: eval with user input is code injection -- use getent to safely resolve home
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6 || true)
    [ -z "$TARGET_HOME" ] && TARGET_HOME="/home/${TARGET_USER}"
fi

info "Target user: ${TARGET_USER} (home: ${TARGET_HOME})"
# Repair a ~/.ssh an earlier run left owned by root (breaks ssh-keygen)
if [ "$TARGET_USER" != "root" ] && [ -d "${TARGET_HOME}/.ssh" ]; then
    chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.ssh"
    chmod 700 "${TARGET_HOME}/.ssh"
fi

# ── SSH Key ───────────────────────────────────────────────────────
if [ "$SSH_METHOD" != "none" ]; then
    next_step "SSH Key Import"
    SSH_DIR="${TARGET_HOME}/.ssh"
    info "Creating SSH directory: ${SSH_DIR}"
    # Create .ssh owned by the user up front: a root-owned .ssh breaks
    # ssh-import-id (runs as the user) and later ssh-keygen for the user.
    install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$SSH_DIR"
    [ -f "${SSH_DIR}/authorized_keys" ] || install -m 600 -o "$TARGET_USER" -g "$TARGET_USER" /dev/null "${SSH_DIR}/authorized_keys"
    SSH_IMPORTED=n

    if [ "$SSH_METHOD" = "github" ]; then
        info "Fetching public keys from github.com/${GH_USER}..."
        KEY_FILE=$(mktemp)
        if curl -fsSL "https://github.com/${GH_USER}.keys" -o "$KEY_FILE"; then
            KEY_COUNT=$(awk 'NF {count++} END {print count+0}' "$KEY_FILE")
            if [ "$KEY_COUNT" -gt 0 ]; then
                # Append only keys not already present
                while IFS= read -r key; do
                    [ -n "$key" ] && ! grep -qxF "$key" "${SSH_DIR}/authorized_keys" && echo "$key" >> "${SSH_DIR}/authorized_keys"
                done < "$KEY_FILE"
                SSH_IMPORTED=y
                ok "Imported ${KEY_COUNT} SSH key(s) from github.com/${GH_USER}"
            else
                warn "GitHub user '${GH_USER}' has no public SSH keys -- add one at https://github.com/settings/keys, then run: ssh-import-id gh:${GH_USER}"
            fi
        else
            warn "Could not fetch github.com/${GH_USER}.keys (bad username or no network) -- skipping key import"
        fi
        rm -f "$KEY_FILE"
    elif [ "$SSH_METHOD" = "paste" ]; then
        info "Adding provided public key to authorized_keys..."
        echo "$SSH_KEY" >> "${SSH_DIR}/authorized_keys"
        SSH_IMPORTED=y
        ok "SSH key added to ${SSH_DIR}/authorized_keys"
    fi

    chown -R "${TARGET_USER}:${TARGET_USER}" "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    chmod 600 "${SSH_DIR}/authorized_keys"
    if [ "$SSH_IMPORTED" = "y" ]; then
        ok "SSH key configured for ${TARGET_USER}"
    else
        warn "No SSH key installed for ${TARGET_USER} -- continuing setup"
    fi
fi

# ── User environment ─────────────────────────────────────────────
next_step "User Environment"
if [ "$TARGET_USER" != "root" ]; then
    install -d -o "$TARGET_USER" -g "$TARGET_USER" "${TARGET_HOME}/Projects"
    ok "${TARGET_HOME}/Projects ready (the p alias goes there)"
fi
if [ -n "$GIT_NAME" ]; then
    command -v git >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y git >/dev/null 2>&1 || true
    if command -v git >/dev/null 2>&1; then
        # Values passed as positional args so quotes in names can't break the command
        if su - "$TARGET_USER" -c 'git config --global user.name "$1" && git config --global user.email "$2" && git config --global init.defaultBranch main' _ "$GIT_NAME" "$GIT_EMAIL"; then
            ok "Git identity: ${GIT_NAME} <${GIT_EMAIL}>"
        else
            warn "Could not set git identity"
        fi
    else
        warn "git not installed -- skipping git identity"
    fi
fi

# ── System basics ─────────────────────────────────────────────────
if [ "$SYS_BASICS" = "y" ]; then
    next_step "Swap, Locale & Time Sync"
    if [ -z "$(swapon --noheadings 2>/dev/null)" ] && [ ! -e /swapfile ]; then
        RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
        SWAP_MB=$(( RAM_MB * 2 )); [ "$SWAP_MB" -gt 4096 ] && SWAP_MB=4096; [ "$SWAP_MB" -lt 1024 ] && SWAP_MB=1024
        info "No swap found -- creating ${SWAP_MB}MB /swapfile..."
        if { fallocate -l "${SWAP_MB}M" /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count="$SWAP_MB" status=none; } \
           && chmod 600 /swapfile && mkswap /swapfile >/dev/null 2>&1 && swapon /swapfile 2>/dev/null; then
            grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
            ok "Swap enabled: ${SWAP_MB}MB (persistent)"
        else
            rm -f /swapfile
            warn "Could not create swap (container or unsupported filesystem?) -- skipped"
        fi
    else
        ok "Swap already present -- unchanged"
    fi
    DEBIAN_FRONTEND=noninteractive apt-get install -y locales >/dev/null 2>&1 || true
    if command -v locale-gen >/dev/null 2>&1; then
        locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
        grep -q '^LANG=' /etc/default/locale 2>/dev/null || update-locale LANG=en_US.UTF-8 2>/dev/null || true
        ok "Locale: en_US.UTF-8 generated"
    fi
    if timedatectl set-ntp true 2>/dev/null; then
        ok "Clock sync (NTP) enabled"
    else
        warn "Could not enable NTP via timedatectl -- skipped"
    fi
fi

# ── Hardening ─────────────────────────────────────────────────────
if [ "$HARDEN" = "y" ]; then
    next_step "Firewall & SSH Hardening"
    DEBIAN_FRONTEND=noninteractive apt-get install -y ufw openssh-server 2>&1 | grep -E "^(Setting up|is already)" || true
    if command -v ufw >/dev/null 2>&1; then
        ufw allow OpenSSH >/dev/null 2>&1 || ufw allow 22/tcp >/dev/null 2>&1 || true
        if [ "$INSTALL_TAILSCALE" = "y" ]; then ufw allow in on tailscale0 >/dev/null 2>&1 || true; fi
        if ufw --force enable >/dev/null 2>&1; then
            ok "UFW firewall on: SSH allowed$([ "$INSTALL_TAILSCALE" = "y" ] && echo ", tailscale0 allowed"), everything else inbound denied"
            if [ "$INSTALL_DOCKER" = "y" ]; then info "Note: Docker-published ports bypass UFW -- bind containers to 127.0.0.1 unless meant to be public"; fi
        else
            warn "Could not enable UFW (container/kernel?) -- skipped"
        fi
    fi
    # Key-only SSH, but ONLY when a key is really installed, so nobody is locked out.
    if [ -s "${TARGET_HOME}/.ssh/authorized_keys" ] && [ -d /etc/ssh/sshd_config.d ]; then
        # 10- sorts before cloud-init's 50-, and sshd uses the first value it sees
        printf '%s\n' "# NixBash setup: key-only SSH" "PasswordAuthentication no" \
            "KbdInteractiveAuthentication no" "PermitRootLogin prohibit-password" > /etc/ssh/sshd_config.d/10-nixbash.conf
        mkdir -p /run/sshd
        if sshd -t 2>/dev/null; then
            systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
            ok "SSH: password login OFF, root login key-only (key found for ${TARGET_USER})"
        else
            rm -f /etc/ssh/sshd_config.d/10-nixbash.conf
            warn "sshd rejected the hardening config -- reverted, SSH unchanged"
        fi
    else
        warn "No SSH key in ${TARGET_HOME}/.ssh/authorized_keys -- leaving password login ON so you are not locked out"
    fi
fi

# ── Essential tools ───────────────────────────────────────────────
if [ "$INSTALL_ESSENTIALS" = "y" ]; then
    next_step "Essential Tools"
    info "Installing core sysadmin packages..."
    echo ""

    ESSENTIAL_GROUPS=(
        "editors:git vim nano tmux mc"
        "networking:nmap mtr traceroute tcpdump net-tools iputils-ping"
        "filesystem:ncdu tree rsync pv lsof unzip wget rclone"
        "security:fail2ban iptables openssh-server"
        "system:nala unattended-upgrades zram-tools python3-pip"
    )

    for group_entry in "${ESSENTIAL_GROUPS[@]}"; do
        group_name="${group_entry%%:*}"
        group_pkgs="${group_entry#*:}"
        info "  📦 ${group_name}: ${group_pkgs}"
        # shellcheck disable=SC2086
        DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confold" install -y $group_pkgs 2>&1 | grep -E "^(Setting up|is already|E: Unable)" | head -20 || true
    done

    echo ""

    # Configure unattended-upgrades non-interactively
    info "Configuring unattended-upgrades (no auto-reboot)..."
    echo 'Unattended-Upgrade::Automatic-Reboot "false";' > /etc/apt/apt.conf.d/51custom-unattended
    ok "Unattended security updates enabled (reboot disabled)"

    # Configure fail2ban
    if command -v fail2ban-server >/dev/null 2>&1; then
        info "Configuring fail2ban with default SSH jail..."
        cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local 2>/dev/null || true
        systemctl enable fail2ban 2>/dev/null || true
        systemctl start fail2ban 2>/dev/null || true
        ok "fail2ban configured (starts on boot)"
    fi

    # Configure zram
    if [ -f /etc/default/zramswap ]; then
        info "Configuring zram swap (zstd compression, 50% of RAM)..."
        echo -e "ALGO=zstd\nPERCENT=50" > /etc/default/zramswap
        systemctl restart zramswap 2>/dev/null || true
        ok "zram swap enabled"
    fi

    ok "Essential tools installed"
fi

# ── Extras ────────────────────────────────────────────────────────
if [ "$INSTALL_EXTRAS" = "y" ]; then
    next_step "Extra Tools"
    info "Installing extras (monitoring, fun, security, hardware)..."
    echo ""

    EXTRA_GROUPS=(
        "monitoring:atop iotop iftop glances bmon dstat vnstat inxi iptraf-ng"
        "security:tor proxychains"
        "hardware:pciutils smartmontools lm-sensors"
        "remote:sshfs cifs-utils autossh ansible"
        "fun:figlet lolcat cowsay cmatrix"
    )

    for group_entry in "${EXTRA_GROUPS[@]}"; do
        group_name="${group_entry%%:*}"
        group_pkgs="${group_entry#*:}"
        info "  📦 ${group_name}: ${group_pkgs}"
        # shellcheck disable=SC2086
        DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confold" install -y $group_pkgs 2>&1 | grep -E "^(Setting up|is already|E: Unable)" | head -20 || true
    done

    echo ""
    ok "Extra tools installed"
fi

# ── Docker ────────────────────────────────────────────────────────
if [ "$INSTALL_DOCKER" = "y" ]; then
    next_step "Docker"
    if command -v docker >/dev/null 2>&1; then
        DOCKER_VER=$(docker --version 2>/dev/null | head -1)
        ok "Docker already installed: ${DOCKER_VER}"
    else
        info "Downloading and installing Docker via get.docker.com..."
        (curl -fsSL https://get.docker.com | sh 2>&1 || true) | tail -5
    fi
    if command -v docker >/dev/null 2>&1; then
        DOCKER_VER=$(docker --version 2>/dev/null | head -1)
        ok "Docker ready: ${DOCKER_VER}"
        if [ "$TARGET_USER" != "root" ]; then
            usermod -aG docker "$TARGET_USER" && ok "${TARGET_USER} can run docker without sudo (re-login required)"
        fi
    else
        warn "Docker install failed -- rerun later: curl -fsSL https://get.docker.com | sudo sh"
    fi
fi

# ── Tailscale ─────────────────────────────────────────────────────
if [ "$INSTALL_TAILSCALE" = "y" ]; then
    next_step "Tailscale"
    if command -v tailscale >/dev/null 2>&1; then
        ok "Tailscale already installed"
    else
        info "Downloading and installing Tailscale..."
        (curl -fsSL https://tailscale.com/install.sh | sh 2>&1 || true) | tail -5
        command -v tailscale >/dev/null 2>&1 && ok "Tailscale installed" || warn "Tailscale install failed -- rerun later: curl -fsSL https://tailscale.com/install.sh | sudo sh"
    fi
    if ! command -v tailscale >/dev/null 2>&1; then
        :
    elif [ -n "$TS_KEY" ]; then
        info "Authenticating with Tailscale using provided auth key..."
        if tailscale up --authkey="$TS_KEY" --accept-routes 2>&1; then
            TS_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
            ok "Tailscale connected — IP: ${TS_IP}"
        else
            warn "Tailscale auth failed (expired or invalid key?) -- run 'sudo tailscale up' to connect"
        fi
    else
        info "Tailscale installed but not authenticated"
        info "Run 'sudo tailscale up' to connect to your tailnet"
    fi
fi

# ── NixBash (always) ─────────────────────────────────────────────
next_step "NixBash Shell Environment"
info "Installing NixBash for ${TARGET_USER}..."
NIXBASH_CMD='curl -fsSL https://raw.githubusercontent.com/nixfred/nixbash/main/install.sh | bash'
if [ "$TARGET_USER" = "root" ]; then
    bash -c "$NIXBASH_CMD" 2>&1 && NIXBASH_OK=y || NIXBASH_OK=n
else
    su - "$TARGET_USER" -c "$NIXBASH_CMD" 2>&1 && NIXBASH_OK=y || NIXBASH_OK=n
fi
if [ "$NIXBASH_OK" = "y" ]; then
    ok "NixBash shell environment installed for ${TARGET_USER}"
else
    warn "NixBash install failed -- rerun as ${TARGET_USER}: ${NIXBASH_CMD}"
fi

# ── Claude Code ───────────────────────────────────────────────────
if [ "$INSTALL_CLAUDE" = "y" ]; then
    next_step "Claude Code"
    info "Downloading Claude Code for ${TARGET_USER}..."
    if su - "$TARGET_USER" -c 'curl -fsSL https://claude.ai/install.sh | bash' 2>&1; then
        ok "Claude Code installed"
    else
        warn "Claude Code install failed — may need manual install later"
    fi
    # FIX: removed duplicate alias injection -- .bashrc already defines ccc/cccc
    ok "Claude Code ready (ccc/cccc aliases included in NixBash)"
fi

# ── Cleanup ───────────────────────────────────────────────────────
next_step "Cleanup"
info "Removing downloaded package files..."
(apt-get autoclean 2>&1 || true) | tail -1
info "Removing unused packages..."
(DEBIAN_FRONTEND=noninteractive apt-get autoremove -y 2>&1 || true) | tail -3
ok "System cleaned up"

# ── Done ──────────────────────────────────────────────────────────
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS_REMAINING=$((ELAPSED % 60))

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}⚡ NixBash Setup Complete! (${MINUTES}m ${SECONDS_REMAINING}s)${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  ${BOLD}What was done:${RESET}"
echo -e "  ✅ System updated and upgraded"
echo -e "  ✅ Hostname: ${GREEN}$(hostname)${RESET} | Timezone: ${GREEN}${NEW_TZ}${RESET}"
[ "$CREATE_USER" = "y" ] && echo -e "  ✅ User ready: ${GREEN}${NEW_USER}${RESET} (sudo NOPASSWD)"
[ -n "$EXISTING_USER" ] && echo -e "  ✅ User set up: ${GREEN}${EXISTING_USER}${RESET}"
[ "$SSH_METHOD" != "none" ] && [ "${SSH_IMPORTED:-n}" = "y" ] && echo -e "  ✅ SSH key imported"
[ "$SSH_METHOD" != "none" ] && [ "${SSH_IMPORTED:-n}" != "y" ] && echo -e "  ⚠️  SSH key NOT imported -- see warning above"
[ "$INSTALL_ESSENTIALS" = "y" ] && echo -e "  ✅ Essential tools installed"
[ "$INSTALL_EXTRAS" = "y" ] && echo -e "  ✅ Extra tools installed"
[ "$INSTALL_DOCKER" = "y" ] && echo -e "  ✅ Docker: ${GREEN}$(docker --version 2>/dev/null | head -1 || echo 'installed')${RESET}"
[ "$INSTALL_TAILSCALE" = "y" ] && echo -e "  ✅ Tailscale: ${GREEN}$(tailscale ip -4 2>/dev/null || echo 'installed — run tailscale up')${RESET}"
[ "$HARDEN" = "y" ] && echo -e "  ✅ Hardening: UFW + $([ -f /etc/ssh/sshd_config.d/10-nixbash.conf ] && echo 'key-only SSH' || echo 'password SSH still ON (no key)')"
[ "$SYS_BASICS" = "y" ] && echo -e "  ✅ Swap, locale, clock sync"
[ -n "$GIT_NAME" ] && echo -e "  ✅ Git identity: ${GIT_NAME}"
[ "${NIXBASH_OK:-n}" = "y" ] && echo -e "  ✅ NixBash shell environment" || echo -e "  ⚠️  NixBash shell environment FAILED -- see warning above"
[ "$INSTALL_CLAUDE" = "y" ] && echo -e "  ✅ Claude Code with aliases"
echo ""
echo -e "  ${BOLD}Connect:${RESET}  ${CYAN}ssh ${TARGET_USER}@$(hostname)${RESET}"
echo -e "  ${BOLD}Activate:${RESET} ${CYAN}source ~/.bashrc${RESET} (or re-login)"
echo ""
echo -e "  ${DIM}Full log: ${LOG_FILE}${RESET}"
if [ -f /var/run/reboot-required ]; then
    echo -e "  ${YELLOW}A reboot is required to finish updates (kernel/libraries).${RESET}"
    if ask_yn "Reboot now?" "n"; then
        info "Rebooting in 5 seconds (Ctrl+C to cancel)..."
        sleep 5
        reboot
    fi
else
    echo -e "  ${YELLOW}Reboot recommended to apply all changes.${RESET}"
fi
echo ""
