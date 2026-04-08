#!/usr/bin/env bash
# NixBash Interactive Setup - Full server provisioning
# https://github.com/nixfred/nixbash
#
# Usage: curl -sL https://raw.githubusercontent.com/nixfred/nixbash/main/setup.sh | bash
#
# Interactive first-boot setup for fresh Linux servers.
# For non-interactive shell-only install, use install.sh instead.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "${CYAN}[NixSetup]${RESET} $*"; }
ok()    { echo -e "${GREEN}[NixSetup]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[NixSetup]${RESET} $*"; }
fail()  { echo -e "${RED}[NixSetup]${RESET} $*"; exit 1; }

ask() {
    local prompt="$1" default="${2:-}" var
    if [ -n "$default" ]; then
        read -rp "$(echo -e "${CYAN}[?]${RESET} ${prompt} [${default}]: ")" var
        echo "${var:-$default}"
    else
        read -rp "$(echo -e "${CYAN}[?]${RESET} ${prompt}: ")" var
        echo "$var"
    fi
}

ask_yn() {
    local prompt="$1" default="${2:-y}" answer
    read -rp "$(echo -e "${CYAN}[?]${RESET} ${prompt} [${default}]: ")" answer
    answer="${answer:-$default}"
    [[ "$answer" =~ ^[Yy] ]]
}

ask_secret() {
    local prompt="$1" var
    read -srp "$(echo -e "${CYAN}[?]${RESET} ${prompt}: ")" var
    echo ""
    echo "$var"
}

# ── Require root ───────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    fail "This script must be run as root (sudo bash setup.sh)"
fi

echo ""
echo -e "${BOLD}${CYAN}⚡ NixBash Interactive Setup${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  Full server provisioning for fresh Linux boxes"
echo -e "  For shell-only install, use ${BOLD}install.sh${RESET} instead"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# ── Step 1: User Setup ────────────────────────────────────────────
echo -e "${BOLD}── User Setup ──${RESET}"
CREATE_USER="n"
if ask_yn "Create a new sudo user?"; then
    CREATE_USER="y"
    NEW_USER=$(ask "Username")
    NEW_PASS=$(ask_secret "Password for ${NEW_USER}")
    if [ -z "$NEW_USER" ] || [ -z "$NEW_PASS" ]; then
        fail "Username and password cannot be empty"
    fi
fi

# ── Step 2: Hostname ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}── System ──${RESET}"
CURRENT_HOST=$(hostname)
NEW_HOST=$(ask "Hostname" "$CURRENT_HOST")

# ── Step 3: Timezone ──────────────────────────────────────────────
CURRENT_TZ=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "UTC")
NEW_TZ=$(ask "Timezone" "$CURRENT_TZ")

# ── Step 4: SSH Key ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}── SSH ──${RESET}"
SSH_METHOD="none"
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

DISABLE_PASS_SSH="n"
if [ "$SSH_METHOD" != "none" ]; then
    if ask_yn "Disable SSH password authentication after key is added?" "y"; then
        DISABLE_PASS_SSH="y"
    fi
fi

# ── Step 5: Optional Components ───────────────────────────────────
echo ""
echo -e "${BOLD}── Components ──${RESET}"
INSTALL_DOCKER=$(ask_yn "Install Docker?" "y" && echo "y" || echo "n")
INSTALL_CLAUDE=$(ask_yn "Install Claude Code?" "y" && echo "y" || echo "n")
INSTALL_TAILSCALE=$(ask_yn "Install Tailscale?" "y" && echo "y" || echo "n")

TS_KEY=""
if [ "$INSTALL_TAILSCALE" = "y" ]; then
    TS_KEY=$(ask "Tailscale auth key (leave blank to authenticate manually)" "")
fi

INSTALL_TOOLS=$(ask_yn "Install full tool suite (50+ packages)?" "y" && echo "y" || echo "n")

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
[ "$DISABLE_PASS_SSH" = "y" ] && echo -e "  SSH Pass:   ${YELLOW}will be disabled${RESET}"
echo -e "  Docker:     $([ "$INSTALL_DOCKER" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
echo -e "  Claude:     $([ "$INSTALL_CLAUDE" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
echo -e "  Tailscale:  $([ "$INSTALL_TAILSCALE" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
echo -e "  Full tools: $([ "$INSTALL_TOOLS" = "y" ] && echo "${GREEN}yes${RESET}" || echo "${YELLOW}no${RESET}")"
echo -e "  NixBash:    ${GREEN}yes (always)${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if ! ask_yn "Proceed with setup?"; then
    warn "Aborted."
    exit 0
fi

echo ""
info "Starting setup..."
echo ""

# ══════════════════════════════════════════════════════════════════
# EXECUTION
# ══════════════════════════════════════════════════════════════════

# ── System update ─────────────────────────────────────────────────
info "Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq
ok "System updated"

# ── Hostname ──────────────────────────────────────────────────────
if [ "$NEW_HOST" != "$CURRENT_HOST" ]; then
    hostnamectl set-hostname "$NEW_HOST" 2>/dev/null || echo "$NEW_HOST" > /etc/hostname
    sed -i "s/127.0.1.1.*/127.0.1.1\t${NEW_HOST}/" /etc/hosts 2>/dev/null || true
    ok "Hostname set to ${NEW_HOST}"
fi

# ── Timezone ──────────────────────────────────────────────────────
timedatectl set-timezone "$NEW_TZ" 2>/dev/null || ln -sf "/usr/share/zoneinfo/${NEW_TZ}" /etc/localtime
ok "Timezone set to ${NEW_TZ}"

# ── Create user ───────────────────────────────────────────────────
if [ "$CREATE_USER" = "y" ]; then
    if id "$NEW_USER" &>/dev/null; then
        warn "User ${NEW_USER} already exists, updating password"
        echo "${NEW_USER}:${NEW_PASS}" | chpasswd
    else
        useradd -m -s /bin/bash -G sudo "$NEW_USER"
        echo "${NEW_USER}:${NEW_PASS}" | chpasswd
        ok "User ${NEW_USER} created"
    fi
    echo "${NEW_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${NEW_USER}"
    chmod 440 "/etc/sudoers.d/${NEW_USER}"
    ok "Sudo NOPASSWD configured for ${NEW_USER}"
    TARGET_USER="$NEW_USER"
    TARGET_HOME=$(eval echo "~${NEW_USER}")
else
    TARGET_USER=$(logname 2>/dev/null || echo "$SUDO_USER" 2>/dev/null || echo "root")
    TARGET_HOME=$(eval echo "~${TARGET_USER}")
fi

# ── SSH Key ───────────────────────────────────────────────────────
if [ "$SSH_METHOD" != "none" ]; then
    SSH_DIR="${TARGET_HOME}/.ssh"
    mkdir -p "$SSH_DIR"

    if [ "$SSH_METHOD" = "github" ]; then
        apt-get install -y -qq ssh-import-id >/dev/null 2>&1 || true
        if command -v ssh-import-id >/dev/null 2>&1; then
            su - "$TARGET_USER" -c "ssh-import-id gh:${GH_USER}" 2>/dev/null && ok "SSH key imported from GitHub (${GH_USER})" || {
                # Fallback: curl the keys directly
                curl -sL "https://github.com/${GH_USER}.keys" >> "${SSH_DIR}/authorized_keys"
                ok "SSH key imported from GitHub (${GH_USER}) via curl"
            }
        else
            curl -sL "https://github.com/${GH_USER}.keys" >> "${SSH_DIR}/authorized_keys"
            ok "SSH key imported from GitHub (${GH_USER})"
        fi
    elif [ "$SSH_METHOD" = "paste" ]; then
        echo "$SSH_KEY" >> "${SSH_DIR}/authorized_keys"
        ok "SSH key added"
    fi

    chown -R "${TARGET_USER}:${TARGET_USER}" "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    chmod 600 "${SSH_DIR}/authorized_keys"
fi

# ── Disable SSH password auth ─────────────────────────────────────
if [ "$DISABLE_PASS_SSH" = "y" ]; then
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
    ok "SSH password authentication disabled"
fi

# ── Full tool suite ───────────────────────────────────────────────
if [ "$INSTALL_TOOLS" = "y" ]; then
    info "Installing full tool suite (this may take a few minutes)..."
    apt-get install -y -qq \
        python3-pip sysbench iftop git sshfs figlet lolcat multitail glances cowsay \
        ncdu nmap net-tools vnstat mc cifs-utils autossh ansiweather inxi htop \
        tor proxychains rclone unzip wget traceroute unattended-upgrades tcpdump \
        zram-tools rsync pv tree lsof vim nano tmux mtr atop irssi pciutils \
        smartmontools stress lm-sensors iptraf-ng iotop ansible iputils-ping \
        fail2ban nala bmon dstat cmatrix iptables openssh-server \
        2>/dev/null || warn "Some packages may not be available on this distro"
    # Configure unattended-upgrades non-interactively
    echo 'Unattended-Upgrade::Automatic-Reboot "false";' > /etc/apt/apt.conf.d/51custom-unattended
    ok "Full tool suite installed"
fi

# ── fail2ban ──────────────────────────────────────────────────────
if command -v fail2ban-server >/dev/null 2>&1; then
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local 2>/dev/null || true
    systemctl enable fail2ban 2>/dev/null && systemctl start fail2ban 2>/dev/null
    ok "fail2ban configured and started"
fi

# ── zram ──────────────────────────────────────────────────────────
if [ -f /etc/default/zramswap ]; then
    echo -e "ALGO=zstd\nPERCENT=50" > /etc/default/zramswap
    systemctl restart zramswap 2>/dev/null || true
    ok "zram configured (zstd, 50%)"
fi

# ── Docker ────────────────────────────────────────────────────────
if [ "$INSTALL_DOCKER" = "y" ]; then
    if command -v docker >/dev/null 2>&1; then
        ok "Docker already installed"
    else
        info "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        usermod -aG docker "$TARGET_USER"
        ok "Docker installed (${TARGET_USER} added to docker group)"
    fi
fi

# ── Tailscale ─────────────────────────────────────────────────────
if [ "$INSTALL_TAILSCALE" = "y" ]; then
    if command -v tailscale >/dev/null 2>&1; then
        ok "Tailscale already installed"
    else
        info "Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh
        ok "Tailscale installed"
    fi
    if [ -n "$TS_KEY" ]; then
        tailscale up --authkey="$TS_KEY" --accept-routes
        ok "Tailscale connected: $(tailscale ip -4 2>/dev/null)"
    else
        info "Run 'sudo tailscale up' to authenticate"
    fi
fi

# ── NixBash (always) ─────────────────────────────────────────────
info "Installing NixBash for ${TARGET_USER}..."
su - "$TARGET_USER" -c 'curl -sL https://raw.githubusercontent.com/nixfred/nixbash/main/install.sh | bash'
ok "NixBash installed for ${TARGET_USER}"

# ── Claude Code ───────────────────────────────────────────────────
if [ "$INSTALL_CLAUDE" = "y" ]; then
    info "Installing Claude Code for ${TARGET_USER}..."
    su - "$TARGET_USER" -c 'curl -fsSL https://claude.ai/install.sh | bash' 2>/dev/null || warn "Claude Code install failed (may need manual install)"
    # Add aliases
    su - "$TARGET_USER" -c 'grep -q "alias ccc=" ~/.bashrc_local 2>/dev/null || echo -e "\nalias ccc=\"claude --dangerously-skip-permissions\"\nalias cccc=\"claude --dangerously-skip-permissions -c\"" >> ~/.bashrc_local'
    ok "Claude Code installed with aliases in .bashrc_local"
fi

# ── Cleanup ───────────────────────────────────────────────────────
apt-get autoclean -qq
apt-get autoremove -y -qq 2>/dev/null || true

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}⚡ NixBash Setup Complete!${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
[ "$CREATE_USER" = "y" ] && echo -e "  Login:  ${CYAN}ssh ${NEW_USER}@$(hostname)${RESET}"
[ "$DISABLE_PASS_SSH" = "y" ] && echo -e "  Auth:   ${YELLOW}key-only (password disabled)${RESET}"
[ "$INSTALL_TAILSCALE" = "y" ] && command -v tailscale >/dev/null 2>&1 && echo -e "  Tailscale: ${GREEN}$(tailscale ip -4 2>/dev/null || echo 'run tailscale up')${RESET}"
echo ""
echo -e "  ${CYAN}Reboot recommended to apply all changes.${RESET}"
echo ""
