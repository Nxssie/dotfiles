-- Hyprland (Lua config). Reference: https://wiki.hypr.land/Configuring/Start/
-- Colors here are the dark-theme defaults; quickshell's Theme.qml pushes the
-- active palette (dark/light) over hyprctl on every toggle, so keep both in sync.

------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Laptop panel: 1080p at 1.5x. Anything plugged in goes to its right at native
-- resolution and 1x, so docking never mirrors or stacks the outputs.
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "0x0",
    scale    = 1.5,
})
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto-right",
    scale    = 1,
})


---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local browser     = "helium-browser"
local terminal    = "ghostty"
local fileManager = "dolphin"


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
-- hl.on("hyprland.start", function ()
--   hl.exec_cmd(terminal)
--   hl.exec_cmd("nm-applet")
--   hl.exec_cmd("waybar & hyprpaper & firefox")
-- end)

hl.on("hyprland.start", function ()
  -- make WAYLAND_DISPLAY/HYPRLAND_INSTANCE_SIGNATURE visible to systemd --user,
  -- then let it own awww-daemon/qs/hypridle (see config/systemd/user/*.service)
  -- so they get auto-restarted if they crash instead of staying dead.
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE")
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE")
  -- graphical-session.target on this system refuses manual start (only PAM/login
  -- manager may start it), so start the units directly instead of via the target
  -- (cliphist-*.service are the wl-paste --watch clipboard history feeders;
  -- hyprpolkitagent.service is the privilege prompt UI, without it polkit requests fail silently)
  hl.exec_cmd("systemctl --user start quickshell.service awww-daemon.service hypridle.service cliphist-text.service cliphist-image.service hyprpolkitagent.service")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Fix: since GTK 4.20, dead keys (tildes/acentos) stop working on Wayland
-- without an input method running. This restores GTK's built-in compose
-- handling for apps like Ghostty. See ghostty-org/ghostty#8899.
hl.env("GTK_IM_MODULE", "simple")

-- Make Qt/KDE Frameworks apps (Dolphin, Kate...) read kdeglobals for their
-- color scheme instead of falling back to the default Qt style. Requires
-- the 'plasma-integration' package.
hl.env("QT_QPA_PLATFORMTHEME", "kde6")


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,

        -- Tokyo Night: Theme.qml darkAccent -> darkAccentSecondary, darkFgDim
        col = {
            active_border   = { colors = {"rgba(7aa2f7ee)", "rgba(bb9af7ee)"}, angle = 45 },
            inactive_border = "rgba(565f89aa)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
        force_split    = 2,    -- Always split to the right/bottom instead of following the cursor position
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        -- awww owns the wallpaper (see Theme.qml); never fall back to the
        -- built-in anime/logo backgrounds if it is late or dead
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "es",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- See https://wiki.hypr.land/Configuring/Basics/Binds/
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal), { desc = "Open terminal" })
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser), { desc = "Open browser" })
local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close(), { desc = "Close window" })
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("qs ipc call powermenu toggle"), { desc = "Power menu: lock/log out/restart/shut down/suspend" })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("pidof hyprlock || ~/.config/hypr/lock.sh"), { desc = "Lock screen" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), { desc = "Open file manager" })
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), { desc = "Toggle floating window" })

-- Restore tiling for every floating window on the current workspace in one shot
-- (undoes stray floats / corner-snaps without having to alt-tab + SUPER+V one by one)
local function retileWorkspace()
    local ws = hl.get_active_workspace()
    if not ws then return end

    for _, w in ipairs(ws:get_windows()) do
        if w.floating then
            hl.dispatch(hl.dsp.window.float({ action = "disable", window = w }))
        end
    end
end

hl.bind(mainMod .. " + SHIFT + V", retileWorkspace, { desc = "Back to tiling (re-tile every floating window on the workspace)" })
hl.bind(mainMod .. " + T", hl.dsp.window.pin({ action = "toggle" }), { desc = "Pin floating window (always visible)" })

-- Z-order for overlapping floating windows: which one draws on top of which
hl.bind(mainMod .. " + Home", hl.dsp.window.bring_to_top(),                     { desc = "Bring window to the front" })
hl.bind(mainMod .. " + End",  hl.dsp.window.alter_zorder({ mode = "bottom" }),  { desc = "Send window to the back" })
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("qs ipc call launcher toggle"), { desc = "Open app launcher" })
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("qs ipc call bindings toggle"), { desc = "Show this keybinding help" })
hl.bind(mainMod .. " + CTRL + V", hl.dsp.exec_cmd("qs ipc call clipboard toggle"), { desc = "Clipboard history" })
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { desc = "Toggle pseudo-tiling" })
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }), { desc = "Maximize window (fills the space, not real fullscreen; see SUPER+SHIFT+F)" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { desc = "Real fullscreen (hides bar/gaps)" })
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), { desc = "Toggle layout split (dwindle only)" })

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }),  { desc = "Focus window left" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { desc = "Focus window right" })
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }),    { desc = "Focus window up" })
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }),  { desc = "Focus window down" })

-- Cycle through every window regardless of layout position (classic alt-tab).
-- Useful when there's no neighbor in the direction you'd otherwise focus()
-- cycle_next alone doesn't raise floating windows, so the focused one could stay
-- buried under other floats; bring it to the top after each cycle
local function cycleAndRaise(forward)
    return function()
        hl.dispatch(hl.dsp.window.cycle_next({ next = forward }))
        hl.dispatch(hl.dsp.window.bring_to_top())
    end
end

hl.bind(mainMod .. " + Tab",         cycleAndRaise(true),  { desc = "Cycle to next window (alt-tab)" })
hl.bind(mainMod .. " + SHIFT + Tab", cycleAndRaise(false), { desc = "Cycle to previous window (alt-tab)" })

-- Reorder the tiling layout from the keyboard: relocates the active window in that
-- direction (re-splitting the tree like a mouse drag would, finding it an available
-- slot), and if the target holds a group it merges into it instead of a plain swap
-- (mainMod+SHIFT+arrows is already resize, see below)
hl.bind(mainMod .. " + ALT + left",  hl.dsp.window.move({ direction = "left",  group_aware = true }), { desc = "Move/reorder window left (group aware)" })
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.move({ direction = "right", group_aware = true }), { desc = "Move/reorder window right (group aware)" })
hl.bind(mainMod .. " + ALT + up",    hl.dsp.window.move({ direction = "up",    group_aware = true }), { desc = "Move/reorder window up (group aware)" })
hl.bind(mainMod .. " + ALT + down",  hl.dsp.window.move({ direction = "down",  group_aware = true }), { desc = "Move/reorder window down (group aware)" })

-- Window groups: stack windows into one tabbed slot, cycle tabs from the keyboard.
-- A fully keyboard-driven alternative to hunting for the right tiling geometry.
hl.bind(mainMod .. " + G",      hl.dsp.group.toggle(), { desc = "Group window into tabs (or ungroup)" })
hl.bind(mainMod .. " + comma",  hl.dsp.group.prev(),   { desc = "Previous tab in group" })
hl.bind(mainMod .. " + period", hl.dsp.group.next(),   { desc = "Next tab in group" })

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"),         { desc = "Show/hide scratchpad" })
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }), { desc = "Move window to scratchpad" })

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { desc = "Next workspace (scroll)" })
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { desc = "Previous workspace (scroll)" })

-- Same, from the keyboard: cycle through existing workspaces without knowing their number
hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "e+1" }), { desc = "Next workspace" })
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.focus({ workspace = "e-1" }), { desc = "Previous workspace" })
hl.bind(mainMod .. " + CTRL + SHIFT + right", hl.dsp.window.move({ workspace = "e+1" }), { desc = "Move window to next workspace" })
hl.bind(mainMod .. " + CTRL + SHIFT + left",  hl.dsp.window.move({ workspace = "e-1" }), { desc = "Move window to previous workspace" })

-- Declutter: jump to / send a window to the first empty workspace instead of hunting for a free number
hl.bind(mainMod .. " + N",         hl.dsp.focus({ workspace = "empty" }),       { desc = "Go to first empty workspace" })
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.window.move({ workspace = "empty" }), { desc = "Move window to first empty workspace" })

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, desc = "Move window by dragging" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, desc = "Resize window by dragging" })

-- Resize the active window with the keyboard (works on floating and tiled windows)
local resizeStep = 30
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -resizeStep, y = 0, relative = true }), { repeating = true, desc = "Shrink window width" })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = resizeStep,  y = 0, relative = true }), { repeating = true, desc = "Grow window width" })
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0, y = -resizeStep, relative = true }), { repeating = true, desc = "Shrink window height" })
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0, y = resizeStep,  relative = true }), { repeating = true, desc = "Grow window height" })

-- Snap the active window to a screen corner as a small floating window
-- (dwindle's pseudotile just centers a shrunk window inside its slot, no corner anchor exists there,
-- so this forces floating + an explicit size/position instead)
local function gapFor(side)
    local gaps = hl.get_config("general.gaps_out")
    if type(gaps) == "table" then
        return gaps[side] or 0
    end
    return gaps or 0
end

-- Space reserved by layer-shell surfaces (bars/docks with an exclusive zone), per side
local function reservedFor(mon, side)
    local r = mon.reserved
    if type(r) == "table" then
        return r[side] or 0
    end
    return r or 0
end

local function snapToCorner(hAlign, vAlign)
    return function()
        local w = hl.get_active_window()
        if not w then return end

        if not w.floating then
            hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
        end

        local mon = hl.get_active_monitor()
        if not mon then return end

        local width, height = 480, 320

        -- mon.width/height are physical pixels; move/resize work in logical (scaled) pixels
        local monW, monH = mon.width / mon.scale, mon.height / mon.scale

        hl.dispatch(hl.dsp.window.resize({ x = width, y = height, relative = false }))

        -- Same gaps_out used by tiled windows, plus any exclusive zone (bars/docks), on each side
        local x = (hAlign == "left")
            and (mon.x + gapFor("left") + reservedFor(mon, "left"))
            or  (mon.x + monW - width - gapFor("right") - reservedFor(mon, "right"))
        local y = (vAlign == "top")
            and (mon.y + gapFor("top") + reservedFor(mon, "top"))
            or  (mon.y + monH - height - gapFor("bottom") - reservedFor(mon, "bottom"))

        hl.dispatch(hl.dsp.window.move({ x = x, y = y, relative = false }))
    end
end

hl.bind(mainMod .. " + CTRL + 1", snapToCorner("left",  "bottom"), { desc = "Snap small window: bottom-left corner" })
hl.bind(mainMod .. " + CTRL + 2", snapToCorner("right", "bottom"), { desc = "Snap small window: bottom-right corner" })
hl.bind(mainMod .. " + CTRL + 3", snapToCorner("left",  "top"),    { desc = "Snap small window: top-left corner" })
hl.bind(mainMod .. " + CTRL + 4", snapToCorner("right", "top"),    { desc = "Snap small window: top-right corner" })
hl.bind(mainMod .. " + CTRL + 5", hl.dsp.window.center(), { desc = "Center floating window" })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, desc = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, desc = "Volume down" })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true, desc = "Mute audio" })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true, desc = "Mute microphone" })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+ && qs ipc call osd brightness"),                  { locked = true, repeating = true, desc = "Brightness up" })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%- && qs ipc call osd brightness"),                  { locked = true, repeating = true, desc = "Brightness down" })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, desc = "Next track" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "Play/pause" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "Play/pause" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, desc = "Previous track" })

-- Screenshots (grim + slurp + swappy). Both save to disk, copy to the clipboard and
-- notify with a thumbnail; the region one quietly aborts if slurp is cancelled (Esc)
local screenshotDir = "$HOME/Pictures/Screenshots"
local function screenshot(cmd)
    return "mkdir -p " .. screenshotDir
        .. " && f=" .. screenshotDir .. "/$(date +%Y%m%d_%H%M%S).png"
        .. " && " .. cmd
        .. " && wl-copy < \"$f\""
        .. " && notify-send -a Screenshot -i \"$f\" 'Screenshot copied to clipboard' \"$(basename \"$f\")\""
end
hl.bind("Print",         hl.dsp.exec_cmd(screenshot("grim \"$f\"")), { desc = "Full-screen screenshot (saves + copies)" })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(screenshot("g=$(slurp) && grim -g \"$g\" - | swappy -f - -o \"$f\" && [ -s \"$f\" ]")), { desc = "Region screenshot + annotate (saves + copies)" })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/


local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Dialogs and utility windows float centered instead of splitting the tiling tree:
-- file choosers, Bitwarden, portal prompts, polkit and the audio/bluetooth tools
hl.window_rule({
    name  = "float-dialogs",
    match = { title = "^(Open|Save|Open File|Save File|Save As|Select|Choose|Abrir|Guardar).*" },
    float = true,
    center = true,
    size  = "60% 70%",
})
hl.window_rule({
    name  = "float-utilities",
    match = { class = "^(Bitwarden|bitwarden|org\\.pulseaudio\\.pavucontrol|pavucontrol|blueman-manager|nm-connection-editor|org\\.kde\\.polkit-kde-authentication-agent-1|hyprpolkitagent|xdg-desktop-portal-gtk|xdg-desktop-portal-kde)$" },
    float = true,
    center = true,
})
hl.window_rule({
    name  = "float-pip",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },
    float = true,
    pin   = true,
    size  = "480 270",
})

-- Blur the quickshell layers (bar, popups, launcher...) so translucent surfaces
-- match the blur already enabled on windows; ignore_alpha keeps fully
-- transparent regions (the gaps around cards) from being blurred
hl.layer_rule({
    name  = "blur-quickshell",
    match = { namespace = "^quickshell:.*" },
    blur = true,
    ignore_alpha = 0.1,
})
