# NixBash - Fast Linux Server Shell Environment
# https://github.com/nixfred/nixbash
# One-liner install: curl -sL https://raw.githubusercontent.com/nixfred/nixbash/main/install.sh | bash && source ~/.bashrc

# Skip for non-interactive shells
[[ $- != *i* ]] && return

######################################################################
# PATH SETUP
######################################################################
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/.bun/bin" && ":$PATH:" != *":$HOME/.bun/bin:"* ]] && export PATH="$HOME/.bun/bin:$PATH"
[[ -d "$HOME/.cargo/bin" && ":$PATH:" != *":$HOME/.cargo/bin:"* ]] && export PATH="$HOME/.cargo/bin:$PATH"

######################################################################
# SYSTEM ALIASES
######################################################################

# FIX: clear aliases that were converted to functions in this version.
# Without this, `source ~/.bashrc` in a shell that loaded the OLD .bashrc
# fails because bash expands the old alias before parsing the new function
# definition, e.g. `si()` becomes `sudo apt install -y()` -> syntax error.
unalias reboot si aa df du psg 2>/dev/null

# Package management (works with or without sudo)
# FIX: function instead of alias -- alias fell through if sudo existed but failed (expired creds, policy, etc.)
reboot() {
  if command -v sudo >/dev/null 2>&1; then
    sudo reboot
  else
    command reboot
  fi
}

# FIX: si is a function because aliases don't expand $@ reliably
si() {
  if command -v sudo >/dev/null 2>&1; then
    sudo apt install -y "$@"
  else
    apt install -y "$@"
  fi
}

# FIX: aa is a function so sudo logic applies to each step, not just the first
# FIX: uses array instead of word-splitting "sudo apt" string -- avoids IFS fragility
aa() {
  local -a APT=(apt)
  command -v sudo >/dev/null 2>&1 && APT=(sudo apt)
  "${APT[@]}" update && "${APT[@]}" upgrade -y && "${APT[@]}" autoremove -y
}

alias eh='command -v sudo >/dev/null && sudo nano /etc/hosts || nano /etc/hosts'

# System info
alias neo='fastfetch 2>/dev/null || neofetch 2>/dev/null || screenfetch 2>/dev/null || echo "Install fastfetch: sudo apt install fastfetch"'
# FIX: renamed from `ip` to `ipa` -- `ip` shadowed the binary, breaking `ip route`, `ip link`, etc.
alias ipa='ip a'
# FIX: df as function -- alias with pipe mangled any user-supplied arguments
df() { command df -hT "$@" | grep -v tmpfs; }
alias myip='curl -s ifconfig.me'
alias temp='vcgencmd measure_temp 2>/dev/null || ([ -f /sys/class/thermal/thermal_zone0/temp ] && echo "temp=$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))C") || echo "N/A"'

# Claude Code
alias ccc='claude --dangerously-skip-permissions'
alias cccc='claude --dangerously-skip-permissions -c'

# Quick launchers
alias p='cd ~/Projects'
# FIX: renamed `1` to `pinglong` -- single-char alias with 100M pings is chaotic neutral
# FIX: uses `command ping` to bypass the -c 5 alias
alias pinglong='command ping 1.1.1.1'
alias ms='msfconsole'
alias gem='gemini --yolo'
alias installclaude='curl -fsSL https://claude.ai/install.sh | bash'
alias installgemini='npm install -g @google/gemini-cli'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias home='cd ~'
alias root='cd /'
alias tmp='cd /tmp'

# File listing
alias l='ls -CFh'
alias ll='ls -alFh'
alias la='ls -Ah'
alias lt='ls -lath'

# File operations
alias cls='clear && ls'
# FIX: renamed from `mkdir` to `mkp` -- overriding mkdir broke scripts expecting plain mkdir behavior
alias mkp='mkdir -pv'
alias wget='wget -c'
alias tarx='tar -xvzf'
alias tarc='tar -cvzf'

# Productivity
alias c='clear'
alias e='exit'
alias sb='source ~/.bashrc'
alias bm='nano ~/.bashrc && source ~/.bashrc'
alias h='history | tail -20'
alias hg='history | grep'
alias now='date +"%T"'
alias nowtime='date +"%d-%m-%Y %T"'
alias reload='source ~/.bashrc'
alias vi='nano'
alias svi='command -v sudo >/dev/null && sudo nano || nano'

# Git
# FIX: gitc is now a function -- the alias had no -m flag and no $@ so it dropped into editor with no message
# Uses "WIP YYYY-MM-DD" as default message if none supplied
gitc() { git add -A && git commit -m "${*:-WIP $(date +%F)}"; }
alias gs='git status'
alias glog='git log --oneline --graph --decorate -20'

# Process and monitoring
# FIX: uses `command top` as final fallback -- bare `top` caused infinite alias recursion
alias top='btop 2>/dev/null || htop -t 2>/dev/null || command top'
alias htop='htop -t'
# FIX: `du` alias used glob `*` which ignored args, caused glob explosion, and broke arg passing
# Renamed to duh() function -- raw `du` command is left untouched
duh() {
  du -sh "$@" 2>/dev/null | sort -h
}
alias memtop='ps aux --sort=-%mem | head -n 15'
alias cputop='ps aux --sort=-%cpu | head -n 15'
alias ports='netstat -tuln 2>/dev/null || ss -tuln'
# FIX: psg and myprocesses had classic grep self-match issue -- grep always found itself in results
psg() { ps aux | grep -i --color=auto "$@" | grep -v grep; }
alias myprocesses='ps -ef | grep -v grep | grep $USER'
alias io='sudo iotop -o 2>/dev/null || echo "Install iotop: sudo apt install iotop"'
alias log='tail -f /var/log/syslog'
alias authlog='sudo tail -f /var/log/auth.log'

# Network
alias ping='ping -c 5'
alias www='python3 -m http.server 8080'
alias json='python3 -m json.tool'
alias urlencode='python3 -c "import sys, urllib.parse as ul; print(ul.quote_plus(sys.argv[1]))"'
alias uuid='python3 -c "import uuid; print(uuid.uuid4())"'
alias timestamp='date +%s'
alias iso8601='date -Iseconds'

# Tailscale shortcuts
alias ts='tailscale status'
alias tsip='tailscale ip -4'

# Find shortcuts
alias ff='find . -name'

######################################################################
# ENHANCED TOOLS (aliases set if installed)
######################################################################

if command -v batcat >/dev/null 2>&1; then
    alias cat='batcat --style=plain'
    alias bat='batcat'
elif command -v bat >/dev/null 2>&1; then
    alias cat='bat --style=plain'
fi

if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first'
    alias lt='eza --tree --icons --level=2'
elif [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto --group-directories-first'
    alias ll='ls -alFh --color=auto --group-directories-first'
    alias la='ls -Ah --color=auto --group-directories-first'
    alias l='ls -CFh --color=auto --group-directories-first'
fi

if command -v colordiff >/dev/null 2>&1; then
    alias diff='colordiff'
else
    alias diff='diff --color=auto'
fi

if command -v tree >/dev/null 2>&1; then
    alias tree='tree -C'
fi

if command -v rg >/dev/null 2>&1; then
    alias rg='rg --smart-case'
fi

# FIX: dropped `-n` from grep -- adding line numbers breaks scripts expecting raw grep output
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

######################################################################
# HISTORY & SHELL OPTIONS
######################################################################

HISTCONTROL=ignoreboth:erasedups
HISTIGNORE="ls:ll:la:cd:cd ..:pwd:exit:date:* --help:history:clear:c"
shopt -s histappend
shopt -s histverify
HISTSIZE=10000
HISTFILESIZE=20000
HISTTIMEFORMAT="%F %T "
shopt -s checkwinsize
shopt -s cdspell
shopt -s dirspell
shopt -s autocd 2>/dev/null
shopt -s globstar 2>/dev/null

# FIX: use append pattern instead of direct assignment -- direct assignment clobbers anything else using PROMPT_COMMAND
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a"

# Better history search
if [[ $- == *i* ]]; then
    bind '"\e[A": history-search-backward'
    bind '"\e[B": history-search-forward'
fi

######################################################################
# PROMPT
######################################################################

RED="\[\033[0;31m\]"
GREEN="\[\033[0;32m\]"
BLUE="\[\033[0;34m\]"
CYAN="\[\033[0;36m\]"
YELLOW="\[\033[0;33m\]"
BOLD_GREEN="\[\033[1;32m\]"
BOLD_BLUE="\[\033[1;34m\]"
BOLD_YELLOW="\[\033[1;33m\]"
BOLD_CYAN="\[\033[1;36m\]"
RESET="\[\033[0m\]"

PS1="${BOLD_GREEN}\u${RESET}${RED}@${RESET}${BOLD_YELLOW}\h${RESET} ${BOLD_BLUE}\w${RESET}${BOLD_CYAN} > ${RESET}"

# Terminal title
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;\u@\h: \w\a\]$PS1"
    ;;
esac

######################################################################
# FUNCTIONS
######################################################################

# Extract any archive format
# FIX: added .tar.xz and .xz which were missing
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.tar.xz)    tar xJf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar e "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.xz)        unxz "$1"        ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Make directory and cd into it
mkcd() {
    mkdir -p "$1" && builtin cd "$1"
}

# cd with auto-ls
cdd() {
    builtin cd "$@" && ls -la
}

# Check what is listening on a given port
# Usage: listening 8080
listening() {
    ss -tlnp | grep ":${1}"
}

# rsync push: push local file/dir to remote
# Usage: push ./localfile user@host:/remote/path
push() {
    rsync -avz --progress "$1" "$2"
}

# rsync pull: pull remote file/dir to current directory
# Usage: pull user@host:/remote/path/file
pull() {
    rsync -avz --progress "$1" .
}

######################################################################
# SYSTEM BANNER
######################################################################

print_system_banner() {
    local CYAN='\033[0;36m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local BLUE='\033[0;34m'
    local PURPLE='\033[0;35m'
    local WHITE='\033[1;37m'
    local RESET='\033[0m'
    local BOLD='\033[1m'

    HOST=$(hostname)
    IPs=$(hostname -I 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | xargs || echo "N/A")
    UPTIME=$(uptime -p 2>/dev/null || echo "N/A")
    LOAD=$(cut -d " " -f1-3 /proc/loadavg 2>/dev/null || echo "N/A")
    DISK=$(df -h / 2>/dev/null | awk 'NR==2 {print $5 " used on " $6}' || echo "N/A")
    MEM=$(free -h 2>/dev/null | awk '/Mem:/ {print $7 " free / " $2}' || echo "N/A")
    DATE=$(date '+%A, %B %d, %Y - %I:%M:%S %p %Z' 2>/dev/null || date)

    # Temperature
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        CELSIUS=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [ -n "$CELSIUS" ]; then
            TEMP="$((CELSIUS / 1000))C"
        else
            TEMP="N/A"
        fi
    else
        TEMP="N/A"
    fi

    # FIX: cache external IP to /tmp with 5-min TTL -- avoids curl on every shell open
    # Skip entirely on SSH connections (light mode)
    if [ -n "$SSH_CONNECTION" ]; then
        EXTERNAL_IP="(skipped on SSH)"
    else
        CACHE_FILE="/tmp/.nixbash_ext_ip"
        if [ -f "$CACHE_FILE" ] && [ -n "$(find "$CACHE_FILE" -mmin -5 2>/dev/null)" ]; then
            EXTERNAL_IP=$(cat "$CACHE_FILE")
        else
            EXTERNAL_IP=$(timeout 2 curl -s ifconfig.me 2>/dev/null || echo "offline")
            echo "$EXTERNAL_IP" > "$CACHE_FILE"
        fi
    fi

    # Tailscale status -- skip heavy status check on SSH connections
    if command -v tailscale >/dev/null 2>&1; then
        if [ -n "$SSH_CONNECTION" ]; then
            TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
            TAILSCALE="${TS_IP:-not connected}"
        else
            TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
            TS_STATUS=$(tailscale status --self 2>/dev/null | awk '{print $NF}' || echo "")
            if [ -n "$TS_IP" ]; then
                TAILSCALE="${TS_IP} (${TS_STATUS:-unknown})"
            else
                TAILSCALE="not connected"
            fi
        fi
    else
        TAILSCALE="Not installed"
    fi

    # Docker status -- skip on SSH connections
    if [ -z "$SSH_CONNECTION" ] && command -v docker >/dev/null 2>&1; then
        DOCKER_RUNNING=$(docker ps -q 2>/dev/null | wc -l)
        DOCKER_TOTAL=$(docker ps -a -q 2>/dev/null | wc -l)
        DOCKER_STATUS="${DOCKER_RUNNING} running / ${DOCKER_TOTAL} total"
    elif command -v docker >/dev/null 2>&1; then
        DOCKER_STATUS="(skipped on SSH)"
    else
        DOCKER_STATUS="Not installed"
    fi

    # SSH failure detection
    SSH_FAILS="None"
    if [ -f /var/log/auth.log ]; then
        SSH_FAIL_COUNT=$(grep "Failed password" /var/log/auth.log 2>/dev/null | tail -n 5 | wc -l)
        if [ "$SSH_FAIL_COUNT" -gt 0 ] 2>/dev/null; then
            SSH_FAILS="$SSH_FAIL_COUNT recent attempts"
        fi
    elif command -v journalctl >/dev/null 2>&1; then
        SSH_FAIL_COUNT=$(journalctl -u ssh --since "24 hours ago" 2>/dev/null | grep -c "Failed password" 2>/dev/null || echo "0")
        if [ "$SSH_FAIL_COUNT" -gt 0 ] 2>/dev/null; then
            SSH_FAILS="$SSH_FAIL_COUNT recent attempts"
        fi
    fi

    echo -e "${BOLD}${BLUE}****************************************************${RESET}"
    echo -e "${BOLD}${CYAN}*  NixBash System Status - $HOST"
    echo -e "${BOLD}${BLUE}****************************************************${RESET}"
    echo -e "${WHITE}*  Host:        ${GREEN}$HOST${RESET}"
    echo -e "${WHITE}*  IPs:         ${CYAN}$IPs${RESET}"
    echo -e "${WHITE}*  External:    ${CYAN}$EXTERNAL_IP${RESET}"
    echo -e "${WHITE}*  Uptime:      ${GREEN}$UPTIME${RESET}"
    echo -e "${WHITE}*  Load:        ${YELLOW}$LOAD${RESET}"
    echo -e "${WHITE}*  Memory:      ${GREEN}$MEM${RESET}"
    echo -e "${WHITE}*  Disk:        ${YELLOW}$DISK${RESET}"
    echo -e "${WHITE}*  Temp:        ${BLUE}$TEMP${RESET}"
    echo -e "${WHITE}*  Tailscale:   ${GREEN}$TAILSCALE${RESET}"
    echo -e "${WHITE}*  Docker:      ${PURPLE}$DOCKER_STATUS${RESET}"
    echo -e "${WHITE}*  SSH Fails:   ${RED}$SSH_FAILS${RESET}"
    echo -e "${BOLD}${BLUE}****************************************************${RESET}"
    echo -e "${WHITE}*  ${DATE}${RESET}"
    echo -e "${BOLD}${BLUE}****************************************************${RESET}"
    echo ""
}

# Show banner on interactive login
if [ -t 1 ] && [ -z "$NIXBASH_NO_BANNER" ]; then
    print_system_banner
fi

######################################################################
# ZOXIDE (smart cd) - if installed
######################################################################
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

######################################################################
# FZF - if installed
######################################################################
if command -v fzf >/dev/null 2>&1; then
    [ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
    [ -f /usr/share/doc/fzf/examples/completion.bash ] && source /usr/share/doc/fzf/examples/completion.bash
fi

######################################################################
# BASH COMPLETION
######################################################################
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

######################################################################
# LOCAL OVERRIDES (create these files for machine-specific config)
######################################################################
[ -f ~/.bashrc_local ] && source ~/.bashrc_local
