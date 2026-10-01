#!/usr/bin/env bash
# setup.sh — apply the Plasma side of the dotfiles (replaces hyprland.lua + quickshell).
#
#   setup.sh              run every step
#   setup.sh STEP...      run only the given steps
#   setup.sh --list       list the steps
#
# Idempotent: safe to re-run after editing shortcuts.tsv, panel.js or this file.
# Needs a running Plasma session (kwriteconfig6 + D-Bus), except for `links`.
# Plasma's own rc files are NOT symlinked into the repo (Plasma rewrites them
# constantly); this script is the source of truth instead.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m ->\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

require_session() {
    [ "${XDG_CURRENT_DESKTOP:-}" = "KDE" ] || die "not in a Plasma session (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset})"
    command -v kwriteconfig6 >/dev/null || die "kwriteconfig6 not found"
}

kw() { kwriteconfig6 "$@"; }
kwin_reconfigure() { qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || warn "kwin reconfigure failed (not running?)"; }

# --- links: custom plasmoids, scripts and launchers --------------------------------
step_links() {
    local src
    mkdir -p "$DATA/plasma/plasmoids" "$DATA/applications" "$HOME/.local/bin"
    for src in "$HERE"/plasmoids/*/; do
        ln -sfn "${src%/}" "$DATA/plasma/plasmoids/$(basename "$src")"
    done
    for src in "$HERE"/applications/*.desktop; do
        ln -sfn "$src" "$DATA/applications/$(basename "$src")"
    done
    mkdir -p "$DATA/kwin/scripts"
    for src in "$HERE"/kwin-scripts/*/; do
        ln -sfn "${src%/}" "$DATA/kwin/scripts/$(basename "$src")"
    done
    for src in "$HERE"/bin/*; do
        chmod +x "$src"
        ln -sfn "$src" "$HOME/.local/bin/$(basename "$src")"
    done
    log "linked plasmoids, KWin scripts, launchers and helpers"
}

# --- workspaces: dynamic (Hyprland-style) — created on demand, empty ones vanish ---------
step_workspaces() {
    step_links
    kw --file kwinrc --group Desktops --key Rows 1
    kw --file kwinrc --group Plugins --key dynamicdesktopsEnabled true
    kwin_reconfigure
    log "workspaces: dynamic (kwin-scripts/dynamicdesktops); Meta+N creates workspace N on demand"
}

# --- kwin: stock KDE window management (floating, titlebars, click to focus) --------
step_kwin() {
    # Undo anything the opt-in tiling step changed: delete the keys so KWin falls
    # back to its own defaults, and switch the tiling script off.
    kw --file kwinrc --group org.kde.kdecoration2 --key NoPlugin --delete
    kw --file kwinrc --group Windows --key FocusPolicy --delete
    kw --file kwinrc --group Windows --key NextFocusPrefersMouse --delete
    kw --file kwinrc --group MouseBindings --key CommandAllKey --delete
    kw --file kwinrc --group MouseBindings --key CommandAll1 --delete
    kw --file kwinrc --group MouseBindings --key CommandAll3 --delete
    kw --file kwinrc --group Plugins --key krohnkiteEnabled false
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript krohnkite >/dev/null 2>&1 || true
    kwin_reconfigure
    log "kwin: stock floating window management (tiling off)"
}

# --- input: touchpad natural scroll (Hyprland: touchpad.natural_scroll) --------------
step_input() {
    local sys base name vendor product found=0
    # busctl prints "<type> <value>"; qdbus6 cannot read these properties
    prop() { busctl --user get-property org.kde.KWin "$1" org.kde.KWin.InputDevice "$2" 2>/dev/null | cut -d' ' -f2-; }
    for sys in $(qdbus6 org.kde.KWin /org/kde/KWin/InputDevice org.kde.KWin.InputDeviceManager.devicesSysNames 2>/dev/null); do
        base="/org/kde/KWin/InputDevice/$sys"
        [ "$(prop "$base" touchpad)" = "true" ] || continue
        name="$(prop "$base" name | sed 's/^"//;s/"$//')"
        vendor="$(prop "$base" vendor)"
        product="$(prop "$base" product)"
        kw --file kcminputrc --group Libinput --group "$vendor" --group "$product" --group "$name" --key NaturalScroll true
        busctl --user set-property org.kde.KWin "$base" org.kde.KWin.InputDevice naturalScroll b true >/dev/null 2>&1 || true
        log "touchpad '$name': natural scroll on"
        found=1
    done
    [ "$found" -eq 1 ] || warn "no touchpad found; natural scroll not configured"
}

# --- screen: laptop panel scale (external monitors land to its right, 1x) -------------
# Hyprland used 1.5; 1.25 suits Plasma better (its popups are sized in font units).
# Override with e.g. `SCREEN_SCALE=1.5 setup.sh screen`.
step_screen() {
    local scale="${SCREEN_SCALE:-1.25}"
    if kscreen-doctor "output.eDP-1.scale.$scale" >/dev/null 2>&1; then
        log "eDP-1 scale $scale"
    else
        warn "could not set eDP-1 scale to $scale"
    fi
}

# --- shortcuts: shortcuts.tsv -> kglobalshortcutsrc ----------------------------------
apply_shortcuts_file() {
    local manifest="$1" rc="$CONFIG/kglobalshortcutsrc" comp action keys desc part cur value
    local -a groups

    # On Wayland kglobalacceld runs inside kwin_wayland and only reads this file at
    # startup, so the new bindings take effect on the next login (not live).
    while IFS='|' read -r comp action keys desc; do
        comp="${comp//[[:space:]]/}"
        [[ -z "$comp" || "$comp" == \#* || "$comp" == help ]] && continue
        action="$(sed 's/^ *//;s/ *$//' <<<"$action")"
        keys="$(sed 's/^ *//;s/ *$//' <<<"$keys")"
        desc="$(sed 's/^ *//;s/ *$//' <<<"$desc")"

        groups=()
        IFS=/ read -ra parts <<<"$comp"
        for part in "${parts[@]}"; do groups+=(--group "$part"); done

        keys="${keys//;/$'\t'}"
        if [ "${parts[0]}" = services ]; then
            # service launchers store just the key list
            value="$keys"
        else
            # keep the existing "default,friendly name" tail so Plasma's own metadata survives
            cur="$(kreadconfig6 --file "$rc" "${groups[@]}" --key "$action" --default '')"
            if [[ "$cur" == *,* ]]; then
                value="$keys,${cur#*,}"
            else
                value="$keys,none,${desc:--}"
            fi
        fi
        kw --file "$rc" "${groups[@]}" --key "$action" "$value"
    done < "$manifest"

    log "shortcuts written from $(basename "$manifest") ($(grep -cE '^[^#[:space:]]' "$manifest") bindings) — log out and back in to activate"
}

step_shortcuts() { apply_shortcuts_file "$HERE/shortcuts.tsv"; }

# --- power: the hypridle chain — 150s dim, 300s lock, 330s screen off, 900s suspend --
step_power() {
    local profile
    for profile in AC Battery LowBattery; do
        kw --file powerdevilrc --group "$profile" --group Display --key DimDisplayWhenIdle true
        kw --file powerdevilrc --group "$profile" --group Display --key DimDisplayIdleTimeoutSec 150
        kw --file powerdevilrc --group "$profile" --group Display --key TurnOffDisplayWhenIdle true
        kw --file powerdevilrc --group "$profile" --group Display --key TurnOffDisplayIdleTimeoutSec 330
        kw --file powerdevilrc --group "$profile" --group Display --key TurnOffDisplayIdleTimeoutWhenLockedSec 30
        kw --file powerdevilrc --group "$profile" --group SuspendAndShutdown --key AutoSuspendAction 1
        kw --file powerdevilrc --group "$profile" --group SuspendAndShutdown --key AutoSuspendIdleTimeoutSec 900
    done
    qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement org.kde.Solid.PowerManagement.reparseConfiguration >/dev/null 2>&1 \
        || systemctl --user restart plasma-powerdevil.service
    log "power: dim 150s, screen off 330s, suspend 900s"
}

# --- lock: kscreenlocker (hyprlock) ---------------------------------------------------
step_lock() {
    kw --file kscreenlockerrc --group Daemon --key Autolock true
    kw --file kscreenlockerrc --group Daemon --key Timeout 5
    kw --file kscreenlockerrc --group Daemon --key LockOnResume true
    kw --file kscreenlockerrc --group Daemon --key LockGrace 0
    log "lock: after 5 min idle and on resume from suspend"
}

# --- spectacle: save + copy + notify, like the grim/slurp bindings ---------------------
step_spectacle() {
    mkdir -p "$HOME/Pictures/Screenshots"
    kw --file spectaclerc --group General --key autoSaveImage true
    kw --file spectaclerc --group General --key clipboardGroup PostScreenshotCopyImage
    kw --file spectaclerc --group General --key quitAfterSaveCopyExport true
    kw --file spectaclerc --group ImageSave --key imageSaveLocation "file://$HOME/Pictures/Screenshots"
    kw --file spectaclerc --group ImageSave --key imageFilenameTemplate "<yyyyMMdd>_<HHmmss>"
    log "spectacle: auto-save to ~/Pictures/Screenshots + copy to clipboard"
}

# --- theme: Tokyo Night dark by default (theme-toggle flips it) ------------------------
step_theme() {
    if [ -L "$CONFIG/kdeglobals" ]; then
        die "$CONFIG/kdeglobals is a symlink into the repo; Plasma rewrites it constantly. Replace it with a real file first (see README: Plasma)."
    fi
    mkdir -p "$DATA/color-schemes"
    [ -e "$DATA/color-schemes/TokyoNightDark.colors" ] || ln -sfn "$HERE/../color-schemes/TokyoNightDark.colors" "$DATA/color-schemes/TokyoNightDark.colors"
    [ -e "$DATA/color-schemes/TokyoNightLight.colors" ] || ln -sfn "$HERE/../color-schemes/TokyoNightLight.colors" "$DATA/color-schemes/TokyoNightLight.colors"
    "$HERE/bin/theme-toggle" "${THEME:-dark}"
    log "theme: ${THEME:-dark}"
}

# --- panel: thin top panel (see panel.js) -----------------------------------------------
step_panel() {
    step_links
    # plasmashell only discovers new plasmoids at startup
    systemctl --user restart plasma-plasmashell.service
    local i
    for i in {1..20}; do
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'print("ok")' >/dev/null 2>&1 && break
        sleep 0.5
    done
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$HERE/panel.js")"
    log "panel rebuilt"
}

# --- tiling (OPT-IN, not in the default run): Krohnkite dwindle-style auto tiling ------
step_tiling() {
    # shellcheck source=tiling.sh
    . "$HERE/tiling.sh"
    log "tiling: krohnkite configured"
}

STEPS=(links workspaces kwin input screen shortcuts power lock spectacle theme panel)
OPTIONAL_STEPS=(tiling)

if [ "${1:-}" = "--list" ]; then printf '%s\n' "${STEPS[@]}"; printf '%s (opt-in)\n' "${OPTIONAL_STEPS[@]}"; exit 0; fi

run=("$@")
[ "${#run[@]}" -gt 0 ] || run=("${STEPS[@]}")

[ "${run[0]}" = links ] && [ "${#run[@]}" -eq 1 ] || require_session
for s in "${run[@]}"; do
    declare -F "step_$s" >/dev/null || die "unknown step: $s (see --list)"
    "step_$s"
done
