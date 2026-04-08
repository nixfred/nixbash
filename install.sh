#!/usr/bin/env bash
# NixBash Installer - Fast Linux Server Shell Environment
# https://github.com/nixfred/nixbash
#
# Usage: curl -sL https://raw.githubusercontent.com/nixfred/nixbash/main/install.sh | bash && source ~/.bashrc
#
# Fully non-interactive. No prompts. Safe for scripted installs.

set -euo pipefail

NIXBASH_REPO="https://raw.githubusercontent.com/nixfred/nixbash/main"
BASHRC_URL="${NIXBASH_REPO}/.bashrc"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$HOME/.bashrc.pre-nixbash.${TIMESTAMP}"
START_TIME=$(date +%s)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

info()  { echo -e "${CYAN}[NixBash]${RESET} $*"; }
ok()    { echo -e "${GREEN}[NixBash]${RESET} ✅ $*"; }
warn()  { echo -e "${YELLOW}[NixBash]${RESET} ⚠️  $*"; }
fail()  { echo -e "${RED}[NixBash]${RESET} ❌ $*"; exit 1; }
step()  { echo -e "\n${BOLD}${CYAN}── Step $1: $2 ──${RESET}"; }

echo ""
echo -e "${BOLD}${CYAN}⚡ NixBash Installer${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${DIM}Installing shell environment for $(whoami)@$(hostname)${RESET}"
echo -e "  ${DIM}$(date '+%Y-%m-%d %H:%M:%S %Z')${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

# ── Step 1: Backup existing .bashrc ──────────────────────────────────
step 1 "Backup"
if [ -f "$HOME/.bashrc" ]; then
    cp "$HOME/.bashrc" "$BACKUP_FILE"
    ok "Backed up existing .bashrc → ${BACKUP_FILE}"
else
    info "No existing .bashrc found, nothing to backup"
fi

# ── Step 2: Detect package manager ───────────────────────────────────
step 2 "Detect Package Manager"

PKG_MANAGER="none"
install_pkg() {
    local pkg="$1"
    if command -v apt-get >/dev/null 2>&1; then
        if command -v sudo >/dev/null 2>&1; then
            sudo apt-get install -y "$pkg" 2>&1 | grep -E "^(Setting up|is already)" || true
        else
            apt-get install -y "$pkg" 2>&1 | grep -E "^(Setting up|is already)" || true
        fi
    elif command -v dnf >/dev/null 2>&1; then
        if command -v sudo >/dev/null 2>&1; then
            sudo dnf install -y "$pkg" 2>&1 | grep -E "^(Installing|already installed)" || true
        else
            dnf install -y "$pkg" 2>&1 | grep -E "^(Installing|already installed)" || true
        fi
    elif command -v pacman >/dev/null 2>&1; then
        if command -v sudo >/dev/null 2>&1; then
            sudo pacman -S --noconfirm "$pkg" 2>&1 | grep -E "^(installing|warning)" || true
        else
            pacman -S --noconfirm "$pkg" 2>&1 | grep -E "^(installing|warning)" || true
        fi
    else
        return 1
    fi
}

if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
    ok "Found apt (Debian/Ubuntu family)"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
    ok "Found dnf (Fedora/RHEL family)"
elif command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
    ok "Found pacman (Arch family)"
else
    warn "No supported package manager found — tool installation will be skipped"
fi

# ── Step 3: Update package lists ─────────────────────────────────────
step 3 "Update Package Lists"
if [ "$PKG_MANAGER" = "apt" ]; then
    info "Running apt update..."
    if command -v sudo >/dev/null 2>&1; then
        sudo apt-get update 2>&1 | tail -1
    else
        apt-get update 2>&1 | tail -1
    fi
    ok "Package lists updated"
elif [ "$PKG_MANAGER" != "none" ]; then
    info "Skipping update for ${PKG_MANAGER} (updates on install)"
fi

# ── Step 4: Install modern CLI tools ─────────────────────────────────
step 4 "Install CLI Tools"

TOOLS_INSTALLED=0
TOOLS_SKIPPED=0
TOOLS_EXISTED=0

install_tool() {
    local cmd="$1"
    local pkg="${2:-$1}"
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "${cmd} — already installed"
        TOOLS_EXISTED=$((TOOLS_EXISTED + 1))
        return 0
    fi
    info "Installing ${cmd}..."
    if install_pkg "$pkg"; then
        ok "${cmd} — installed"
        TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
    else
        warn "${cmd} — could not be installed (skipped)"
        TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    fi
}

# bat (called batcat on Debian/Ubuntu)
if ! command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    install_tool batcat bat
else
    ok "bat — already installed"
    TOOLS_EXISTED=$((TOOLS_EXISTED + 1))
fi

install_tool fzf fzf
install_tool rg ripgrep
install_tool tree tree
install_tool htop htop
install_tool btop btop
install_tool ncdu ncdu
install_tool curl curl

# fastfetch (replaces neofetch)
if ! command -v fastfetch >/dev/null 2>&1; then
    install_tool fastfetch fastfetch
else
    ok "fastfetch — already installed"
    TOOLS_EXISTED=$((TOOLS_EXISTED + 1))
fi

# eza - may need a separate repo on older distros
if ! command -v eza >/dev/null 2>&1; then
    info "Installing eza..."
    if install_pkg eza; then
        ok "eza — installed"
        TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
    else
        warn "eza — not available in default repos (skipped — ls colors still work)"
        TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    fi
else
    ok "eza — already installed"
    TOOLS_EXISTED=$((TOOLS_EXISTED + 1))
fi

# zoxide - may need manual install on older distros
if ! command -v zoxide >/dev/null 2>&1; then
    info "Installing zoxide..."
    if install_pkg zoxide; then
        ok "zoxide — installed"
        TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
    else
        info "Trying zoxide official installer as fallback..."
        if curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash 2>&1 | tail -1; then
            ok "zoxide — installed (via official script)"
            TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
        else
            warn "zoxide — not available (skipped)"
            TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
        fi
    fi
else
    ok "zoxide — already installed"
    TOOLS_EXISTED=$((TOOLS_EXISTED + 1))
fi

echo ""
info "Tool summary: ${GREEN}${TOOLS_INSTALLED} installed${RESET}, ${CYAN}${TOOLS_EXISTED} already present${RESET}$([ "$TOOLS_SKIPPED" -gt 0 ] && echo ", ${YELLOW}${TOOLS_SKIPPED} skipped${RESET}")"

# ── Step 5: Download NixBash .bashrc ─────────────────────────────────
step 5 "Download NixBash Configuration"
info "Fetching .bashrc from ${BASHRC_URL}..."
if curl -sL "$BASHRC_URL" -o "$HOME/.bashrc"; then
    BASHRC_SIZE=$(wc -c < "$HOME/.bashrc")
    ALIAS_COUNT=$(grep -c "^alias " "$HOME/.bashrc" 2>/dev/null || echo "0")
    ok "NixBash .bashrc installed (${BASHRC_SIZE} bytes, ${ALIAS_COUNT} aliases)"
else
    fail "Failed to download .bashrc from ${BASHRC_URL}"
fi

# ── Done ─────────────────────────────────────────────────────────────
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}⚡ NixBash installed successfully!${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  Tools:     ${GREEN}${TOOLS_INSTALLED} new${RESET} + ${CYAN}${TOOLS_EXISTED} existing${RESET}"
[ "$TOOLS_SKIPPED" -gt 0 ] && echo -e "  Skipped:   ${YELLOW}${TOOLS_SKIPPED}${RESET}"
[ -f "$BACKUP_FILE" ] && echo -e "  Backup:    ${CYAN}${BACKUP_FILE}${RESET}"
echo -e "  Time:      ${CYAN}${ELAPSED}s${RESET}"
echo ""
echo -e "  Run ${CYAN}source ~/.bashrc${RESET} or open a new terminal to activate."
echo -e "  Add local overrides to ${CYAN}~/.bashrc_local${RESET}"
echo ""
