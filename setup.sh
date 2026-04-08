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

START_TIME=$(date +%s)

echo ""
echo -e "${BOLD}${CYAN}⚡ NixBash Interactive Setup${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  Full server provisioning for fresh Linux boxes"
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
if ask_yn "Create a new sudo user?"; then
    CREATE_USER="y"
    NEW_USER=$(ask "Username")
    while true; do
        NEW_PASS=$(ask_secret "Password for ${NEW_USER}")
        NEW_PASS2=$(ask_secret "Confirm password")
        if [ -z "$NEW_PASS" ]; then
            warn "Password cannot be empty — try again"
        elif [ "$NEW_PASS" != "$NEW_PASS2" ]; then
            warn "Passwords do not match — try again"
        else
            ok "Password confirmed"
            break
        fi
    done
    if [ -z "$NEW_USER" ]; then
        fail "Username cannot be empty"
    fi
fi

# ── Hostname ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── System ──${RESET}"
CURRENT_HOST=$(hostname)
NEW_HOST=$(ask "Hostname" "$CURRENT_HOST")

# ── Timezone ──────────────────────────────────────────────────────
CURRENT_TZ=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "UTC")
NEW_TZ=$(ask "Timezone" "$CURRENT_TZ")

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
        GH_USER=$(ask "GitHub username")
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
    TS_KEY=$(ask "Tailscale auth key (leave blank to authenticate manually)" "")
fi

if ask_yn "Install essential tools (20 packages: git, vim, tmux, nmap, rsync, etc.)?" "y"; then INSTALL_ESSENTIALS="y"; else INSTALL_ESSENTIALS="n"; fi
if ask_yn "Install extras (monitoring, fun, security — 30+ more packages)?" "n"; then INSTALL_EXTRAS="y"; else INSTALL_EXTRAS="n"; fi

# ── Confirmation ──────────────────────────────────────────────────
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  Setup Summary${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
[ "$CREATE_USER" = "y" ] && echo -e "  User:       ${GREEN}${NEW_USER}${RESET} (sudo, NOPASSWD)"
echo -e "  Hostname:   ${GREEN}${NEW_HOST}${RESET}"
echo -e "  Timezone:   ${GREEN}${NEW_TZ}${RESET}"
[ "$SSH_METHOD" = "github" ] && echo -e "  SSH Key:    ${GREEN}from github.com/${GH_USER}${RESET}"
[ "$SSH_METHOD" = "paste" ] && echo -e "  SSH Key:    ${GREEN}manual paste${RESET}"
echo -e "  Docker:     $([ "$INSTALL_DOCKER" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
echo -e "  Claude:     $([ "$INSTALL_CLAUDE" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
echo -e "  Tailscale:  $([ "$INSTALL_TAILSCALE" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
echo -e "  Essentials: $([ "$INSTALL_ESSENTIALS" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
echo -e "  Extras:     $([ "$INSTALL_EXTRAS" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
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
TOTAL_STEPS=4  # update, hostname/tz, nixbash, cleanup — always present
[ "$CREATE_USER" = "y" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$SSH_METHOD" != "none" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$INSTALL_ESSENTIALS" = "y" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$INSTALL_EXTRAS" = "y" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$INSTALL_DOCKER" = "y" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$INSTALL_TAILSCALE" = "y" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$INSTALL_CLAUDE" = "y" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))

CURRENT_STEP=0
next_step() { CURRENT_STEP=$((CURRENT_STEP + 1)); step "$CURRENT_STEP" "$1"; }

echo ""
echo -e "${BOLD}${GREEN}🚀 Starting setup — ${TOTAL_STEPS} steps to go...${RESET}"

# ── System update ─────────────────────────────────────────────────
next_step "System Update"
info "Updating package lists..."
apt-get update 2>&1 | tail -3
info "Upgrading installed packages..."
apt-get upgrade -y 2>&1 | tail -5
ok "System packages are up to date"

# ── Hostname & Timezone ──────────────────────────────────────────
next_step "Hostname & Timezone"
if [ "$NEW_HOST" != "$CURRENT_HOST" ]; then
    info "Changing hostname: ${CURRENT_HOST} → ${NEW_HOST}"
    hostnamectl set-hostname "$NEW_HOST" 2>/dev/null || echo "$NEW_HOST" > /etc/hostname
    sed -i "s/127.0.1.1.*/127.0.1.1\t${NEW_HOST}/" /etc/hosts 2>/dev/null || true
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
        apt-get install -y sudo 2>&1 | grep -E "^(Setting up|is already)" || true
        ok "sudo installed"
    fi
    if id "$NEW_USER" &>/dev/null; then
        warn "User '${NEW_USER}' already exists — updating password only"
        echo "${NEW_USER}:${NEW_PASS}" | chpasswd
    else
        info "Creating user '${NEW_USER}' with home directory and bash shell..."
        useradd -m -s /bin/bash -G sudo "$NEW_USER"
        echo "${NEW_USER}:${NEW_PASS}" | chpasswd
        ok "User '${NEW_USER}' created — home dir: /home/${NEW_USER}"
    fi
    info "Granting passwordless sudo..."
    mkdir -p /etc/sudoers.d
    echo "${NEW_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${NEW_USER}"
    chmod 440 "/etc/sudoers.d/${NEW_USER}"
    ok "Sudo NOPASSWD configured — ${NEW_USER} can run any command without password"
    TARGET_USER="$NEW_USER"
    TARGET_HOME=$(eval echo "~${NEW_USER}")
else
    TARGET_USER=$(logname 2>/dev/null || echo "${SUDO_USER:-root}")
    TARGET_HOME=$(eval echo "~${TARGET_USER}")
fi

# ── SSH Key ───────────────────────────────────────────────────────
if [ "$SSH_METHOD" != "none" ]; then
    next_step "SSH Key Import"
    SSH_DIR="${TARGET_HOME}/.ssh"
    info "Creating SSH directory: ${SSH_DIR}"
    mkdir -p "$SSH_DIR"

    if [ "$SSH_METHOD" = "github" ]; then
        info "Fetching public keys from github.com/${GH_USER}..."
        apt-get install -y ssh-import-id 2>&1 | grep -E "^(Setting up|is already)" || true
        if command -v ssh-import-id >/dev/null 2>&1; then
            if su - "$TARGET_USER" -c "ssh-import-id gh:${GH_USER}" 2>&1; then
                ok "SSH key imported from GitHub user '${GH_USER}'"
            else
                info "ssh-import-id failed, trying direct curl fallback..."
                KEY_COUNT=$(curl -sL "https://github.com/${GH_USER}.keys" | tee -a "${SSH_DIR}/authorized_keys" | wc -l)
                ok "Imported ${KEY_COUNT} SSH key(s) from GitHub via curl"
            fi
        else
            KEY_COUNT=$(curl -sL "https://github.com/${GH_USER}.keys" | tee -a "${SSH_DIR}/authorized_keys" | wc -l)
            ok "Imported ${KEY_COUNT} SSH key(s) from GitHub"
        fi
    elif [ "$SSH_METHOD" = "paste" ]; then
        info "Adding provided public key to authorized_keys..."
        echo "$SSH_KEY" >> "${SSH_DIR}/authorized_keys"
        ok "SSH key added to ${SSH_DIR}/authorized_keys"
    fi

    info "Setting permissions: ${SSH_DIR} (700), authorized_keys (600)"
    chown -R "${TARGET_USER}:${TARGET_USER}" "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    chmod 600 "${SSH_DIR}/authorized_keys"
    ok "SSH key configured for ${TARGET_USER}"
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
        apt-get install -y $group_pkgs 2>&1 | grep -E "^(Setting up|is already|E: Unable)" | head -20 || true
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
        systemctl enable fail2ban 2>/dev/null && systemctl start fail2ban 2>/dev/null
        ok "fail2ban active — protecting SSH against brute force"
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
        apt-get install -y $group_pkgs 2>&1 | grep -E "^(Setting up|is already|E: Unable)" | head -20 || true
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
        curl -fsSL https://get.docker.com | sh 2>&1 | tail -5
        info "Adding ${TARGET_USER} to docker group..."
        usermod -aG docker "$TARGET_USER"
        DOCKER_VER=$(docker --version 2>/dev/null | head -1)
        ok "Docker installed: ${DOCKER_VER}"
        ok "${TARGET_USER} can run docker without sudo (re-login required)"
    fi
fi

# ── Tailscale ─────────────────────────────────────────────────────
if [ "$INSTALL_TAILSCALE" = "y" ]; then
    next_step "Tailscale"
    if command -v tailscale >/dev/null 2>&1; then
        ok "Tailscale already installed"
    else
        info "Downloading and installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh 2>&1 | tail -5
        ok "Tailscale installed"
    fi
    if [ -n "$TS_KEY" ]; then
        info "Authenticating with Tailscale using provided auth key..."
        tailscale up --authkey="$TS_KEY" --accept-routes 2>&1
        TS_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
        ok "Tailscale connected — IP: ${TS_IP}"
    else
        info "Tailscale installed but not authenticated"
        info "Run 'sudo tailscale up' to connect to your tailnet"
    fi
fi

# ── NixBash (always) ─────────────────────────────────────────────
next_step "NixBash Shell Environment"
info "Installing NixBash for ${TARGET_USER}..."
su - "$TARGET_USER" -c 'curl -sL https://raw.githubusercontent.com/nixfred/nixbash/main/install.sh | bash' 2>&1
ok "NixBash shell environment installed for ${TARGET_USER}"

# ── Claude Code ───────────────────────────────────────────────────
if [ "$INSTALL_CLAUDE" = "y" ]; then
    next_step "Claude Code"
    info "Downloading Claude Code for ${TARGET_USER}..."
    if su - "$TARGET_USER" -c 'curl -fsSL https://claude.ai/install.sh | bash' 2>&1; then
        ok "Claude Code installed"
    else
        warn "Claude Code install failed — may need manual install later"
    fi
    info "Adding Claude Code aliases to ~/.bashrc_local..."
    su - "$TARGET_USER" -c 'grep -q "alias ccc=" ~/.bashrc_local 2>/dev/null || echo -e "\nalias ccc=\"claude --dangerously-skip-permissions\"\nalias cccc=\"claude --dangerously-skip-permissions -c\"" >> ~/.bashrc_local'
    ok "Aliases added: ccc (skip permissions), cccc (skip + continue)"
fi

# ── Cleanup ───────────────────────────────────────────────────────
next_step "Cleanup"
info "Removing downloaded package files..."
apt-get autoclean 2>&1 | tail -1
info "Removing unused packages..."
apt-get autoremove -y 2>&1 | tail -3
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
[ "$CREATE_USER" = "y" ] && echo -e "  ✅ User created: ${GREEN}${NEW_USER}${RESET} (sudo NOPASSWD)"
[ "$SSH_METHOD" != "none" ] && echo -e "  ✅ SSH key imported"
[ "$INSTALL_ESSENTIALS" = "y" ] && echo -e "  ✅ Essential tools installed"
[ "$INSTALL_EXTRAS" = "y" ] && echo -e "  ✅ Extra tools installed"
[ "$INSTALL_DOCKER" = "y" ] && echo -e "  ✅ Docker: ${GREEN}$(docker --version 2>/dev/null | head -1 || echo 'installed')${RESET}"
[ "$INSTALL_TAILSCALE" = "y" ] && echo -e "  ✅ Tailscale: ${GREEN}$(tailscale ip -4 2>/dev/null || echo 'installed — run tailscale up')${RESET}"
echo -e "  ✅ NixBash shell environment"
[ "$INSTALL_CLAUDE" = "y" ] && echo -e "  ✅ Claude Code with aliases"
echo ""
[ "$CREATE_USER" = "y" ] && echo -e "  ${BOLD}Connect:${RESET}  ${CYAN}ssh ${NEW_USER}@$(hostname)${RESET}"
echo -e "  ${BOLD}Activate:${RESET} ${CYAN}source ~/.bashrc${RESET} (or re-login)"
echo ""
echo -e "  ${YELLOW}Reboot recommended to apply all changes.${RESET}"
echo ""
