# NixBash

Fast, clean bash environment for Linux servers. One command to set up aliases, prompt, system banner, and modern CLI tools on any fresh server.

## Quick Install

```bash
curl -sL https://raw.githubusercontent.com/nixfred/nixbash/main/install.sh | bash && source ~/.bashrc
```

## What You Get

**System Banner** — hostname, IPs, uptime, load, memory, disk, temp, Docker status, SSH fail attempts on every login

**Prompt** — `user@host ~/dir ➜` with colors (green user, yellow host, blue dir, cyan arrow)

**70+ Aliases** — package management, navigation, file ops, monitoring, networking

**Modern CLI Tools** (auto-installed):
- `eza` — better `ls` with icons
- `bat` — better `cat` with syntax highlighting
- `fzf` — fuzzy finder
- `zoxide` — smart `cd` that learns
- `ripgrep` — fast recursive search
- `htop` — better `top`
- `tree` — directory visualization

**Functions:**
- `extract <file>` — auto-detect and extract any archive (.tar.gz, .zip, .7z, .rar, etc.)
- `mkcd <dir>` — create directory and cd into it
- `cdd <dir>` — cd and auto-list contents

## Alias Reference

| Alias | Command | Description |
|-------|---------|-------------|
| **Package Management** |||
| `aa` | `apt update && upgrade && autoremove` | Full system update |
| `si` | `apt install -y` | Quick install |
| **Navigation** |||
| `..` | `cd ..` | Up one |
| `...` | `cd ../..` | Up two |
| `....` | `cd ../../..` | Up three |
| `home` | `cd ~` | Home directory |
| **Files** |||
| `ll` | `ls -la` (or `eza -la`) | Detailed listing |
| `lt` | `ls -lat` (or `eza --tree`) | Tree/time sorted |
| `cls` | `clear && ls` | Clear and list |
| **Monitoring** |||
| `ports` | `netstat -tuln` | Open ports |
| `memtop` | `ps aux --sort=-%mem` | Top memory consumers |
| `cputop` | `ps aux --sort=-%cpu` | Top CPU consumers |
| `psg` | `ps aux \| grep` | Find process |
| `myip` | `curl ifconfig.me` | External IP |
| **Productivity** |||
| `c` | `clear` | Clear screen |
| `e` | `exit` | Exit shell |
| `sb` | `source ~/.bashrc` | Reload config |
| `bm` | `nano ~/.bashrc && source` | Edit and reload |
| `h` | `history \| tail -20` | Recent history |
| `hg` | `history \| grep` | Search history |

## Local Overrides

Add machine-specific config (SSH aliases, API keys, custom paths) to:

```bash
~/.bashrc_local
```

This file is sourced automatically and won't be overwritten by NixBash updates.

## Uninstall

```bash
# Restore your original .bashrc
cp ~/.bashrc.pre-nixbash.* ~/.bashrc
source ~/.bashrc
```

## Requirements

- Linux with bash
- `curl` (for install)
- `apt`, `dnf`, or `pacman` (for tool installation)
- Works on: Ubuntu, Debian, Raspberry Pi OS, Fedora, Arch, and derivatives

## License

MIT
