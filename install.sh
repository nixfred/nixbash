#!/usr/bin/env bash
# NixBash Installer - Fast Linux Server Shell Environment
# https://github.com/nixfred/nixbash
#
# Usage: curl -sL https://raw.githubusercontent.com/nixfred/nixbash/main/install.sh | bash
#
# Fully non-interactive. No prompts. Safe for scripted installs.

set -euo pipefail

NIXBASH_REPO="https://raw.githubusercontent.com/nixfred/nixbash/main"
BASHRC_URL="${NIXBASH_REPO}/.bashrc"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$HOME/.bashrc.pre-nixbash.${TIMESTAMP}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

info()  { echo -e "${CYAN}[NixBash]${RESET} $*"; }
ok()    { echo -e "${GREEN}[NixBash]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[NixBash]${RESET} $*"; }
fail()  { echo -e "${RED}[NixBash]${RESET} $*"; exit 1; }

echo ""
echo -e "${CYAN}⚡ NixBash Installer${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# ── Step 1: Backup existing .bashrc ──────────────────────────────────
if [ -f "$HOME/.bashrc" ]; then
    cp "$HOME/.bashrc" "$BACKUP_FILE"
    ok "Backed up existing .bashrc → ${BACKUP_FILE}"
else
    info "No existing .bashrc found, skipping backup"
fi

# ── Step 2: Detect package manager ───────────────────────────────────
install_pkg() {
    local pkg="$1"
    if command -v apt-get >/dev/null 2>&1; then
        if command -v sudo >/dev/null 2>&1; then
            sudo apt-get install -y -qq "$pkg" >/dev/null 2>&1
        else
            apt-get install -y -qq "$pkg" >/dev/null 2>&1
        fi
    elif command -v dnf >/dev/null 2>&1; then
        if command -v sudo >/dev/null 2>&1; then
            sudo dnf install -y -q "$pkg" >/dev/null 2>&1
        else
            dnf install -y -q "$pkg" >/dev/null 2>&1
        fi
    elif command -v pacman >/dev/null 2>&1; then
        if command -v sudo >/dev/null 2>&1; then
            sudo pacman -S --noconfirm --quiet "$pkg" >/dev/null 2>&1
        else
            pacman -S --noconfirm --quiet "$pkg" >/dev/null 2>&1
        fi
    else
        return 1
    fi
}

# ── Step 3: Install modern CLI tools ─────────────────────────────────
info "Installing modern CLI tools..."

# Update package lists first (silent)
if command -v apt-get >/dev/null 2>&1; then
    if command -v sudo >/dev/null 2>&1; then
        sudo apt-get update -qq >/dev/null 2>&1 || true
    else
        apt-get update -qq >/dev/null 2>&1 || true
    fi
fi

TOOLS_INSTALLED=0
TOOLS_SKIPPED=0

install_tool() {
    local cmd="$1"
    local pkg="${2:-$1}"
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "  $cmd already installed"
        return 0
    fi
    if install_pkg "$pkg"; then
        ok "  $cmd installed"
        TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
    else
        warn "  $cmd could not be installed (skipped)"
        TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    fi
}

# bat (called batcat on Debian/Ubuntu)
if ! command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    install_tool batcat bat
else
    ok "  bat already installed"
fi

install_tool fzf fzf
install_tool rg ripgrep
install_tool tree tree
install_tool htop htop
install_tool curl curl

# eza - may need a separate repo on older distros
if ! command -v eza >/dev/null 2>&1; then
    if install_pkg eza; then
        ok "  eza installed"
        TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
    else
        warn "  eza not available in default repos (skipped - ls colors still work)"
        TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    fi
else
    ok "  eza already installed"
fi

# zoxide - may need manual install on older distros
if ! command -v zoxide >/dev/null 2>&1; then
    if install_pkg zoxide; then
        ok "  zoxide installed"
        TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
    else
        # Try the official installer as fallback
        if curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash >/dev/null 2>&1; then
            ok "  zoxide installed (via official script)"
            TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
        else
            warn "  zoxide not available (skipped)"
            TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
        fi
    fi
else
    ok "  zoxide already installed"
fi

# ── Step 4: Download NixBash .bashrc ─────────────────────────────────
info "Downloading NixBash .bashrc..."
if curl -sL "$BASHRC_URL" -o "$HOME/.bashrc"; then
    ok "NixBash .bashrc installed"
else
    fail "Failed to download .bashrc from ${BASHRC_URL}"
fi

# ── Step 5: Done ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}⚡ NixBash installed successfully!${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  Tools installed: ${GREEN}${TOOLS_INSTALLED}${RESET}"
[ "$TOOLS_SKIPPED" -gt 0 ] && echo -e "  Tools skipped:   ${YELLOW}${TOOLS_SKIPPED}${RESET}"
[ -f "$BACKUP_FILE" ] && echo -e "  Backup at:       ${CYAN}${BACKUP_FILE}${RESET}"
echo ""
echo -e "  Run ${CYAN}source ~/.bashrc${RESET} or open a new terminal to activate."
echo -e "  Add local overrides to ${CYAN}~/.bashrc_local${RESET}"
echo ""
