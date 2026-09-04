#!/usr/bin/env bash
# install.sh — idempotent bootstrap for the dotfiles repo.
#
# Turns this repo into the source of truth by symlinking whole config dirs
# (stow semantics, no stow dependency). Existing real files/dirs are backed up
# to <target>.bak.<timestamp>, never deleted. Runtime state that lives inside
# linked dirs (secrets.fish, theme_state.json) is migrated from the backup so
# nothing is lost when re-running on an already-configured machine.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m ->\033[0m %s\n' "$*"; }

# link <repo_path> <target_path>
# Replaces target with a symlink to the repo path, backing up anything that
# isn't already the right symlink.
link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        return
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        local bak="${dst}.bak.${STAMP}"
        warn "backing up $dst -> $bak"
        mv "$dst" "$bak"
    fi

    ln -s "$src" "$dst"
    log "linked $dst -> $src"

    # Migrate gitignored runtime files from the fresh backup into the linked
    # dir, so re-running on a live machine keeps secrets and state.
    if [ -d "${dst}.bak.${STAMP}" ]; then
        local f
        for f in "conf.d/secrets.fish" "theme_state.json"; do
            if [ -f "${dst}.bak.${STAMP}/$f" ] && [ ! -e "${dst}/$f" ]; then
                mkdir -p "$(dirname "${dst}/$f")"
                cp "${dst}.bak.${STAMP}/$f" "${dst}/$f"
                warn "migrated runtime file $f"
            fi
        done
    fi
}

# --- ~/.config ---------------------------------------------------------------
link "$REPO/config/hypr"        "$HOME/.config/hypr"
link "$REPO/config/quickshell"  "$HOME/.config/quickshell"
link "$REPO/config/fish"        "$HOME/.config/fish"
link "$REPO/config/ghostty"     "$HOME/.config/ghostty"
link "$REPO/config/zed"         "$HOME/.config/zed"
link "$REPO/config/kdeglobals"  "$HOME/.config/kdeglobals"
link "$REPO/config/starship"    "$HOME/.config/starship"

# --- Theming assets ----------------------------------------------------------
link "$REPO/config/color-schemes"    "$HOME/.local/share/color-schemes"
link "$REPO/assets/wallpapers"       "$HOME/Pictures/Wallpapers"

# --- ssh config --------------------------------------------------------------
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
if [ -L "$HOME/.ssh/config" ] || [ ! -e "$HOME/.ssh/config" ]; then
    link "$REPO/config/ssh/config" "$HOME/.ssh/config"
else
    warn "~/.ssh/config exists and is not a symlink — merge git.nxssie.dev (port 2222) manually"
fi
chmod 600 "$HOME/.ssh/config"

# --- fish secrets ------------------------------------------------------------
if [ ! -e "$HOME/.config/fish/conf.d/secrets.fish" ]; then
    cp "$REPO/config/fish/conf.d/secrets.fish.example" \
       "$HOME/.config/fish/conf.d/secrets.fish"
    warn "seeded secrets.fish from template — fill in the real values"
fi

# --- systemd user units ------------------------------------------------------
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user enable --now ssh-agent.socket 2>/dev/null \
        || warn "ssh-agent.socket not available (install openssh first)"
    sudo systemctl enable --now bluetooth.service 2>/dev/null \
        || warn "bluetooth.service not available (install bluez first)"
    # PulseAudio-API apps (Chromium & co.) need pipewire-pulse running
    systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null \
        || warn "pipewire user units not available (install pipewire-pulse first)"
fi

chmod +x "$REPO/config/hypr/lock.sh"

# --- Manual steps ------------------------------------------------------------
cat <<'EOF'

Done. Remaining one-time/manual steps on a fresh install:

  1. Packages:      sudo pacman -S --needed - < packages/pacman.txt
                    paru -S --needed -    < packages/aur.txt
  2. SDDM theme:    git clone https://github.com/xCaptaiN09/pixie-sddm.git
                    sudo cp -r pixie-sddm /usr/share/sddm/themes/pixie
                    sudo cp system/sddm/theme.conf /etc/sddm.conf.d/theme.conf
  3. mise runtimes: git clone git@github.com:Nxssie/harnxss.git (config.toml
                    is symlinked from there), then: mise install
  4. Secrets:       edit ~/.config/fish/conf.d/secrets.fish, then: exec fish

EOF
