import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

Rectangle {
    id: root
    signal activated()

    visible: UPower.displayDevice.isLaptopBattery
    width: row.implicitWidth + 12
    height: 18
    radius: 0
    color: Theme.muted

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: {
                const s = UPower.displayDevice.state;
                const pct = UPower.displayDevice.percentage * 100;
                if (s === UPowerDeviceState.Charging || s === UPowerDeviceState.PendingCharge)
                    return ""; // nf-fa-bolt
                if (s === UPowerDeviceState.FullyCharged)
                    return ""; // nf-fa-plug
                if (pct >= 90)
                    return ""; // nf-fa-battery_full
                if (pct >= 65)
                    return ""; // nf-fa-battery_three_quarters
                if (pct >= 40)
                    return ""; // nf-fa-battery_half
                if (pct >= 15)
                    return ""; // nf-fa-battery_quarter
                return ""; // nf-fa-battery_empty
            }
            font.family: "Symbols Nerd Font"
            font.pixelSize: 12
            color: {
                const pct = UPower.displayDevice.percentage * 100;
                const charging = UPower.displayDevice.state === UPowerDeviceState.Charging;
                if (charging)
                    return Theme.accent;
                if (pct <= 15)
                    return Theme.red;
                if (pct <= 30)
                    return Theme.yellow;
                return Theme.fg;
            }
        }

        Text {
            text: Math.round(UPower.displayDevice.percentage * 100) + "%"
            color: {
                const pct = UPower.displayDevice.percentage * 100;
                const charging = UPower.displayDevice.state === UPowerDeviceState.Charging;
                if (!charging && pct <= 15)
                    return Theme.red;
                if (!charging && pct <= 30)
                    return Theme.yellow;
                return Theme.fg;
            }
            font.family: "monospace"
            font.pixelSize: 11
            font.bold: true
        }
    }
}
