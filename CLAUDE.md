# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

NixBash is a public, single-purpose repo that bootstraps a clean bash environment on fresh Linux servers. It's designed for rapid server provisioning — one curl command installs everything. The repo lives at github.com/nixfred/nixbash.

## Repo Structure

- `.bashrc` — The complete bash environment (aliases, prompt, banner, functions, tool integrations). This is the deliverable — it gets downloaded directly to `~/.bashrc` on target machines.
- `install.sh` — Non-interactive installer. Backs up existing .bashrc, installs CLI tools via apt/dnf/pacman, downloads .bashrc. Must never prompt the user (no `read`, no `select`, no confirmations) because it's used inside automation scripts.
- `README.md` — Contains the one-liner install command. This is the primary user interface.
- `LICENSE` — MIT.

## Critical Rules

### No Secrets Ever
This is a **public repo**. Never add API keys, tokens, passwords, internal IPs, private hostnames, or SSH aliases to specific machines. Machine-specific config belongs in `~/.bashrc_local` which is sourced at the end of .bashrc but never committed.

### Installer Must Be Non-Interactive
`install.sh` runs via `curl | bash` and inside provisioning scripts. Every package install uses `-y`/`--noconfirm`. No `read` prompts. No user confirmation dialogs. Silent failures are acceptable; blocking prompts are not.

### Aliases Use Fallback Patterns
Many aliases handle missing tools gracefully: `command -v sudo >/dev/null && sudo ... || ...`. Enhanced tool aliases (eza, bat, rg) are wrapped in `command -v` checks so the .bashrc works even if tool installation partially fails.

## Architecture Patterns

### Tool Detection Cascade
The .bashrc uses a priority system for enhanced tools: if `eza` is installed, `ls`/`ll`/`lt` use eza; otherwise fall back to `ls --color=auto` with dircolors. Same pattern for `bat`/`batcat` → plain `cat`, `colordiff` → `diff --color`. New tool integrations should follow this pattern.

### Package Manager Abstraction
`install.sh` has an `install_pkg()` function that abstracts apt-get/dnf/pacman. When adding new tool installations, use `install_tool` (which wraps `install_pkg`) rather than calling package managers directly.

### Local Override Hook
`~/.bashrc_local` is sourced last, allowing per-machine customization without forking the repo. This is where users put SSH aliases, API keys, and machine-specific paths.

### Banner Suppression
The login banner can be disabled with `export NIXBASH_NO_BANNER=1` in `~/.bashrc_local`.

## Testing Changes

There's no test suite. To validate changes:

```bash
# Syntax check the bashrc
bash -n .bashrc

# Syntax check the installer
bash -n install.sh

# Test installer locally (will overwrite your .bashrc — backup first)
bash install.sh

# Verify aliases load
source .bashrc && alias | grep -c alias
```

## Commit and Push Workflow

Changes go directly to `main` — no branches, no PRs. After editing:

```bash
git add -A && git commit -m "description" && git push
```

Note: raw.githubusercontent.com caches for ~5 minutes. Freshly pushed changes may not be immediately available via the curl installer.
