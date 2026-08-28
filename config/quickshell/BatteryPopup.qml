import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower

PopupWindow {
    id: root
    property var anchorWindow
    // rect (in anchorWindow coords) of the chip that opened this popup — see AudioPopup.
    property rect anchorRect: Qt.rect(0, 0, 0, 0)

    signal dismissed()

    anchor.window: anchorWindow
    anchor.rect.x: anchorRect.x + anchorRect.width - width
    anchor.rect.y: anchorWindow ? anchorWindow.height : 0
    implicitWidth: 240
    implicitHeight: content.implicitHeight + 24
    color: Theme.surface
    grabFocus: true

    onVisibleChanged: if (!root.visible) root.dismissed()

    readonly property var device: UPower.displayDevice

    function stateLabel(s) {
        switch (s) {
        case UPowerDeviceState.Charging: return "Charging"
        case UPowerDeviceState.Discharging: return "Discharging"
        case UPowerDeviceState.FullyCharged: return "Full"
        case UPowerDeviceState.PendingCharge: return "Pending charge"
        case UPowerDeviceState.PendingDischarge: return "Pending discharge"
        case UPowerDeviceState.Empty: return "Empty"
        default: return "Unknown"
        }
    }

    function fmtTime(seconds) {
        if (!seconds || seconds <= 0)
            return "—"
        const h = Math.floor(seconds / 3600)
        const m = Math.floor((seconds % 3600) / 60)
        return h > 0 ? (h + "h " + m + "m") : (m + "m")
    }

    function healthColor(pct) {
        if (pct <= 60)
            return Theme.red
        if (pct <= 80)
            return Theme.yellow
        return Theme.fg
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        Text {
            text: Math.round(root.device.percentage * 100) + "%"
            color: Theme.fgBright
            font.family: "monospace"
            font.pixelSize: 22
            font.bold: true
        }

        Text {
            text: root.stateLabel(root.device.state)
            color: Theme.fg
            font.family: "monospace"
            font.pixelSize: 11
        }

        Canvas {
            id: historyCanvas
            width: parent.width
            height: 56
            renderStrategy: Canvas.Cooperative

            Connections {
                target: Battery
                function onHistoryChanged() { historyCanvas.requestPaint() }
            }
            Connections {
                target: Theme
                function onDarkChanged() { historyCanvas.requestPaint() }
            }
            Component.onCompleted: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                const hist = Battery.history
                if (hist.length < 2) {
                    ctx.fillStyle = Theme.fgDim
                    ctx.font = "11px monospace"
                    ctx.fillText("Collecting history…", 2, height / 2 + 4)
                    return
                }

                const pad = 2
                const w = width - pad * 2
                const h = height - pad * 2
                const minT = hist[0].t
                const spanT = Math.max(1, hist[hist.length - 1].t - minT)
                const xAt = i => pad + ((hist[i].t - minT) / spanT) * w
                const yAt = i => pad + h - (hist[i].pct / 100) * h

                ctx.beginPath()
                ctx.moveTo(xAt(0), h + pad)
                for (let i = 0; i < hist.length; i++)
                    ctx.lineTo(xAt(i), yAt(i))
                ctx.lineTo(xAt(hist.length - 1), h + pad)
                ctx.closePath()
                const grad = ctx.createLinearGradient(0, 0, 0, height)
                grad.addColorStop(0, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35))
                grad.addColorStop(1, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.02))
                ctx.fillStyle = grad
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(xAt(0), yAt(0))
                for (let i = 1; i < hist.length; i++)
                    ctx.lineTo(xAt(i), yAt(i))
                ctx.strokeStyle = Theme.accent
                ctx.lineWidth = 1.5
                ctx.stroke()
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.muted
        }

        RowLayout {
            width: parent.width
            Text { text: "Time remaining"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 11; Layout.fillWidth: true }
            Text {
                text: root.device.state === UPowerDeviceState.Charging
                    ? root.fmtTime(root.device.timeToFull)
                    : root.fmtTime(root.device.timeToEmpty)
                color: Theme.fg
                font.family: "monospace"
                font.pixelSize: 11
            }
        }

        RowLayout {
            width: parent.width
            visible: Battery.healthSupported
            Text { text: "Health"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 11; Layout.fillWidth: true }
            Text {
                text: Math.round(Battery.healthPercentage) + "%"
                color: root.healthColor(Battery.healthPercentage)
                font.family: "monospace"
                font.pixelSize: 11
            }
        }

        RowLayout {
            width: parent.width
            visible: Battery.energyFullDesignWh > 0
            Text { text: "Capacity"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 11; Layout.fillWidth: true }
            Text {
                text: Battery.energyFullWh.toFixed(1) + " / " + Battery.energyFullDesignWh.toFixed(1) + " Wh"
                color: Theme.fg
                font.family: "monospace"
                font.pixelSize: 11
            }
        }

        RowLayout {
            width: parent.width
            visible: Battery.cycleCount >= 0
            Text { text: "Charge cycles"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 11; Layout.fillWidth: true }
            Text { text: Battery.cycleCount; color: Theme.fg; font.family: "monospace"; font.pixelSize: 11 }
        }

        RowLayout {
            width: parent.width
            visible: root.device.changeRate !== 0
            Text { text: "Draw"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 11; Layout.fillWidth: true }
            Text { text: Math.abs(root.device.changeRate).toFixed(1) + " W"; color: Theme.fg; font.family: "monospace"; font.pixelSize: 11 }
        }

        RowLayout {
            width: parent.width
            visible: !!(Battery.realBatteryDevice && Battery.realBatteryDevice.model)
            Text { text: "Model"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 11; Layout.fillWidth: true }
            Text { text: Battery.realBatteryDevice ? Battery.realBatteryDevice.model : ""; color: Theme.fg; font.family: "monospace"; font.pixelSize: 11 }
        }
    }
}
