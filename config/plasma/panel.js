// Plasma shell script: rebuilds the panel layout (run by setup.sh through
// `qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript`).
//
// Two panels. The first mirrors the old quickshell bar: a thin top panel with workspaces on the left,
// the clock in the middle and status chips on the right
// (Claude usage, theme toggle, volume, network, bluetooth, brightness, battery);
// media controller, notifications and clipboard live in the tray, which hides them while idle.

// Drop every existing panel (the default bottom panel on a fresh install, or the
// result of a previous run) so the script is idempotent.
panels().forEach(function (p) { p.remove() })

var panel = new Panel()
panel.location = "top"
panel.height = 26
panel.hiding = "none"
panel.alignment = "left"
panel.lengthMode = "fill"
try { panel.floating = false } catch (e) {}

function configure(widget, group, values) {
    widget.currentConfigGroup = [group]
    Object.keys(values).forEach(function (key) { widget.writeConfig(key, values[key]) })
}

// ---- Left: workspace indicator (numbers only, like the bar's "1 2 3") ----------
var pager = panel.addWidget("org.kde.plasma.pager")
configure(pager, "General", { displayedText: "Number", showWindowIcons: "false" })

// ---- Centre: clock — "Thu 01 Oct  09:39:16" ------------------------------------
// Custom clock: the stock digital clock's popup is ~570x460 logical px and is not
// configurable, so dev.nxssie.clock ships a compact month grid instead.
panel.addWidget("org.kde.plasma.panelspacer")
panel.addWidget("dev.nxssie.clock")
panel.addWidget("org.kde.plasma.panelspacer")

// ---- Right: chips ---------------------------------------------------------------
panel.addWidget("dev.nxssie.claudeusage")
panel.addWidget("dev.nxssie.themetoggle")
panel.addWidget("org.kde.plasma.volume")
panel.addWidget("org.kde.plasma.networkmanagement")
panel.addWidget("org.kde.plasma.bluetooth")
panel.addWidget("org.kde.plasma.brightness")
var battery = panel.addWidget("org.kde.plasma.battery")
configure(battery, "General", { showPercentage: "true" })

// Everything above lives in the panel itself, so the tray only keeps the extras
// that have no chip of their own (in this Plasma version the tray's item list is
// stored on the tray applet itself).
var tray = panel.addWidget("org.kde.plasma.systemtray")
configure(tray, "General", {
    extraItems: [
        "org.kde.plasma.mediacontroller",
        "org.kde.plasma.notifications",
        "org.kde.plasma.clipboard",
        "org.kde.plasma.devicenotifier",
        "org.kde.plasma.keyboardlayout"
    ].join(",")
})

// ---- Dock (macOS-style): floating, centered, pinned apps + running windows ---------
// Icons-only task manager: pinned launchers stay, open windows get an indicator.
// Icon size follows the panel thickness (roughly thickness - 8).
// hiding: "dodgewindows" hides it only while a window overlaps it (visible on a clear desktop);
// "autohide" always hides it until the pointer touches the bottom edge; "none" keeps it visible.
var dock = new Panel()
dock.location = "bottom"
dock.height = 40
dock.hiding = "dodgewindows"
dock.alignment = "center"
dock.lengthMode = "fit"
try { dock.floating = true } catch (e) {}

var tasks = dock.addWidget("org.kde.plasma.icontasks")
configure(tasks, "General", {
    launchers: [
        "applications:com.mitchellh.ghostty.desktop",
        "applications:helium.desktop",
        "applications:org.kde.dolphin.desktop",
        "applications:dev.zed.Zed.desktop",
        "applications:bitwarden.desktop"
    ].join(","),
    showOnlyCurrentDesktop: "false"
})
