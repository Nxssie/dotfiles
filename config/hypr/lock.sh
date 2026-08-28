#!/usr/bin/env bash
# Generates hyprlock.conf from hyprlock.conf.tpl based on quickshell's
# active theme (~/.config/quickshell/theme_state.json), then runs hyprlock.
set -euo pipefail

STATE_FILE="$HOME/.config/quickshell/theme_state.json"
TEMPLATE="$HOME/.config/hypr/hyprlock.conf.tpl"
OUT_DIR="$HOME/.cache/hypr"
OUT_FILE="$OUT_DIR/hyprlock.conf"

mkdir -p "$OUT_DIR"

dark=true
if grep -q '"dark"[[:space:]]*:[[:space:]]*false' "$STATE_FILE" 2>/dev/null; then
    dark=false
fi

if [ "$dark" = true ]; then
    wallpaper="$HOME/Pictures/Wallpapers/dark.png"
    bg="rgba(26, 27, 38, 1.0)"
    outer="rgba(41, 46, 66, 1.0)"
    inner="rgba(26, 27, 38, 0.9)"
    font="rgba(192, 202, 245, 1.0)"
    check="rgba(122, 162, 247, 1.0)"
    fail="rgba(247, 118, 142, 1.0)"
    dim="##565f89"
    hour="rgba(83, 134, 242, 1.0)"
    minute="rgba(146, 174, 235, 1.0)"
    date="rgba(169, 177, 214, 1.0)"
else
    wallpaper="$HOME/Pictures/Wallpapers/light.png"
    bg="rgba(250, 243, 224, 1.0)"
    outer="rgba(227, 213, 174, 1.0)"
    inner="rgba(250, 243, 224, 0.9)"
    font="rgba(31, 43, 26, 1.0)"
    check="rgba(47, 82, 51, 1.0)"
    fail="rgba(161, 58, 58, 1.0)"
    dim="##7c8567"
    hour="rgba(69, 230, 87, 1.0)"
    minute="rgba(119, 217, 130, 1.0)"
    date="rgba(61, 74, 53, 1.0)"
fi

sed \
    -e "s|__WALLPAPER__|$wallpaper|g" \
    -e "s|__BG__|$bg|g" \
    -e "s|__OUTER__|$outer|g" \
    -e "s|__INNER__|$inner|g" \
    -e "s|__FONT__|$font|g" \
    -e "s|__CHECK__|$check|g" \
    -e "s|__FAIL__|$fail|g" \
    -e "s|__DIM__|$dim|g" \
    -e "s|__HOUR__|$hour|g" \
    -e "s|__MINUTE__|$minute|g" \
    -e "s|__DATE__|$date|g" \
    "$TEMPLATE" > "$OUT_FILE"

exec hyprlock -c "$OUT_FILE"
