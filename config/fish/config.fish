if status is-interactive
    # Commands to run in interactive sessions can go here
end

if status is-login
    if test -z "$WAYLAND_DISPLAY" -a "$XDG_VTNR" = 1
        exec start-hyprland
    end
end
export PATH="$HOME/.local/bin:$PATH"

# mise — single version manager for all runtimes (bun, node, python, ...)
mise activate fish | source

# Keep the starship preset in sync with the quickshell theme toggle
# (~/.config/quickshell/theme_state.json), so a light/dark switch is
# picked up on the next prompt without restarting the shell.
function __starship_sync_theme --on-event fish_prompt
    set -l state_file "$HOME/.config/quickshell/theme_state.json"
    set -l config "$HOME/.config/starship/dark.toml"
    if test -f "$state_file"; and string match -qr '"dark"\s*:\s*false' -- (cat "$state_file")
        set config "$HOME/.config/starship/light.toml"
    end
    set -gx STARSHIP_CONFIG "$config"
end

starship init fish | source
