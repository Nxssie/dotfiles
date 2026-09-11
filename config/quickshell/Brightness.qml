pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Backlight level straight from sysfs (no brightnessctl process). sysfs attributes
// don't emit inotify events, so there is nothing to watch: the brightness key binds
// call `qs ipc call osd brightness` after brightnessctl, which triggers reload().
Singleton {
    id: root

    readonly property string device: "intel_backlight"
    readonly property string sysfs: "/sys/class/backlight/" + device

    readonly property bool available: maxFile.text() !== ""
    readonly property int max: parseInt(maxFile.text()) || 1
    readonly property int current: parseInt(curFile.text()) || 0
    readonly property real level: Math.max(0, Math.min(1, current / max))

    function reload() {
        curFile.reload()
    }

    FileView {
        id: maxFile
        path: root.sysfs + "/max_brightness"
    }

    FileView {
        id: curFile
        path: root.sysfs + "/brightness"
    }
}
