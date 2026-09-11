pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property alias dark: state.dark

    function toggle() {
        state.dark = !state.dark
    }

    readonly property string wallpaperDark:  Quickshell.env("HOME") + "/Pictures/Wallpapers/dark.png"
    readonly property string wallpaperLight: Quickshell.env("HOME") + "/Pictures/Wallpapers/light.png"

    onDarkChanged: {
        applySystemTheme()
        stateFile.writeAdapter()
    }
    Component.onCompleted: applySystemTheme()

    function applySystemTheme() {
        wallpaperRunner.command = ["awww", "img", dark ? wallpaperDark : wallpaperLight]
        wallpaperRunner.running = true

        // Propagates the mode to the freedesktop portal (org.freedesktop.appearance color-scheme),
        // which is what browsers/apps with "auto" theme detection query.
        var iconTheme = dark ? "breeze-dark" : "breeze"
        colorSchemeRunner.command = ["bash", "-c",
            "gsettings set org.gnome.desktop.interface color-scheme " + (dark ? "prefer-dark" : "prefer-light") +
            " && gsettings set org.gnome.desktop.interface icon-theme " + iconTheme]
        colorSchemeRunner.running = true

        // Propagates the mode to Qt/KDE Frameworks apps (Dolphin, Kate...) by writing
        // the active color scheme to kdeglobals and notifying already-open apps
        // over D-Bus to hot-reload it (without plasmashell/kded, nothing else
        // would do it for us).
        var kdeScheme = dark ? "TokyoNightDark" : "TokyoNightLight"
        var kdeName = dark ? "Tokyo Night Dark" : "Tokyo Night Light"
        qtThemeRunner.command = ["bash", "-c",
            "kwriteconfig6 --file kdeglobals --group General --key ColorScheme " + kdeScheme +
            " && kwriteconfig6 --file kdeglobals --group General --key Name '" + kdeName + "'" +
            " && kwriteconfig6 --file kdeglobals --group Icons --key Theme " + iconTheme +
            " && dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:0 int32:0"]
        qtThemeRunner.running = true

        // Keeps Hyprland's window borders on the same palette as the bar. The
        // Lua config only carries the dark defaults (it can't read this file),
        // so the live values are pushed here on every toggle (`hyprctl keyword`
        // is legacy-parser only; Lua configs need `eval`). Derive from `dark`
        // rather than the active tokens: this handler can run before those
        // bindings re-evaluate, which left the borders one toggle behind.
        var hex = function (c) { return String(c).slice(1, 7) }
        var a1 = dark ? darkAccent : lightAccent
        var a2 = dark ? darkAccentSecondary : lightAccentSecondary
        var dim = dark ? darkFgDim : lightFgDim
        hyprRunner.command = ["hyprctl", "eval",
            'hl.config({ general = { col = { ' +
            'active_border = { colors = {"rgba(' + hex(a1) + 'ee)", "rgba(' + hex(a2) + 'ee)"}, angle = 45 }, ' +
            'inactive_border = "rgba(' + hex(dim) + 'aa)" } } })']
        hyprRunner.running = true
    }

    Process {
        id: wallpaperRunner
        command: ["true"]
    }

    Process {
        id: hyprRunner
        command: ["true"]
    }

    Process {
        id: colorSchemeRunner
        command: ["true"]
    }

    Process {
        id: qtThemeRunner
        command: ["true"]
    }

    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.config/quickshell/theme_state.json"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false

        adapter: JsonAdapter {
            id: state
            property bool dark: true
        }
    }

    // ---- Dark: Tokyo Night ----
    readonly property color darkBg:              "#13141c"
    readonly property color darkSurface:          "#1a1b26"
    readonly property color darkMuted:            "#292e42"
    readonly property color darkFg:               "#a9b1d6"
    readonly property color darkFgBright:         "#c0caf5"
    readonly property color darkFgDim:            "#565f89"
    readonly property color darkAccent:           "#7aa2f7"
    readonly property color darkAccentSecondary:  "#bb9af7"
    readonly property color darkRed:              "#f7768e"
    readonly property color darkYellow:           "#e0af68"

    // ---- Light: crema + verdes oscuros ----
    readonly property color lightBg:              "#ede0c4"
    readonly property color lightSurface:         "#faf3e0"
    readonly property color lightMuted:           "#e3d5ae"
    readonly property color lightFg:              "#3d4a35"
    readonly property color lightFgBright:        "#1f2b1a"
    readonly property color lightFgDim:           "#7c8567"
    readonly property color lightAccent:          "#2f5233"
    readonly property color lightAccentSecondary: "#55692f"
    readonly property color lightRed:             "#a13a3a"
    readonly property color lightYellow:          "#8a6d1f"

    // ---- Active tokens ----
    readonly property color bg:              dark ? darkBg              : lightBg
    readonly property color surface:         dark ? darkSurface         : lightSurface
    readonly property color muted:           dark ? darkMuted           : lightMuted
    readonly property color fg:              dark ? darkFg              : lightFg
    readonly property color fgBright:        dark ? darkFgBright        : lightFgBright
    readonly property color fgDim:           dark ? darkFgDim           : lightFgDim
    readonly property color accent:          dark ? darkAccent          : lightAccent
    readonly property color accentSecondary: dark ? darkAccentSecondary : lightAccentSecondary
    readonly property color red:             dark ? darkRed             : lightRed
    readonly property color yellow:          dark ? darkYellow          : lightYellow
}
