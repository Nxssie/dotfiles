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
