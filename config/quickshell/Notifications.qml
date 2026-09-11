import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications

// Desktop notification daemon (org.freedesktop.Notifications) + popup stack in the
// top-right corner, under the bar. Without this every notify-send / download /
// battery warning is silently dropped. Popups auto-expire (critical ones don't),
// click on the body runs the default action or dismisses, buttons run actions.
PanelWindow {
    id: root
    screen: Quickshell.screens[0]

    // Only occupy the screen while there's something to show, so the layer never
    // eats clicks meant for the windows below it.
    property int count: 0
    visible: count > 0

    anchors.top: true
    anchors.right: true
    margins.top: 8
    margins.right: 8
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property int popupWidth: 380
    readonly property int defaultTimeoutMs: 6000

    implicitWidth: popupWidth
    implicitHeight: Math.max(1, column.implicitHeight)

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: false

        onNotification: notif => {
            notif.tracked = true
        }
    }

    IpcHandler {
        target: "notifications"
        // qs ipc call notifications dismissAll
        function dismissAll(): void {
            for (const n of [...server.trackedNotifications.values]) n.dismiss()
        }
    }

    // ObjectModel.values isn't a NOTIFYable property, track the size ourselves
    Connections {
        target: server.trackedNotifications
        function onValuesChanged() { root.count = server.trackedNotifications.values.length }
    }

    ColumnLayout {
        id: column
        width: root.popupWidth
        spacing: 8

        Repeater {
            model: server.trackedNotifications

            delegate: Rectangle {
                id: card
                required property Notification modelData

                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                // `image` is either pixel data (image://notifimage/...) or, for `-i name`,
                // an icon URL. Resolve icon names ourselves: the image://icon provider paints
                // a checkerboard for names the theme lacks, iconPath(name, true) returns ""
                readonly property string iconSource: {
                    const img = String(modelData.image)
                    const prefix = "image://icon/"
                    if (img.startsWith(prefix)) return Quickshell.iconPath(img.slice(prefix.length), true)
                    if (img !== "") return img
                    return modelData.appIcon !== "" ? Quickshell.iconPath(modelData.appIcon, true) : ""
                }
                readonly property bool hasImage: iconSource !== ""

                Layout.fillWidth: true
                implicitHeight: body.implicitHeight + 24
                color: Theme.surface
                border.width: 1
                border.color: card.critical ? Theme.red : Theme.muted

                // Fade in; Repeater removes the item when the notification is dropped
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 150 } }

                // Auto-dismiss unless the sender asked to persist (timeout 0) or it's critical
                Timer {
                    interval: card.modelData.expireTimeout > 0 ? card.modelData.expireTimeout : root.defaultTimeoutMs
                    running: !card.critical && card.modelData.expireTimeout !== 0 && !hover.hovered
                    onTriggered: card.modelData.expire()
                }

                HoverHandler { id: hover }

                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onTapped: (_, button) => {
                        if (button === Qt.LeftButton) {
                            const def = card.modelData.actions.find(a => a.identifier === "default")
                            if (def) def.invoke()
                            else card.modelData.dismiss()
                        } else {
                            card.modelData.dismiss()
                        }
                    }
                }

                // Urgency accent stripe
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    color: card.critical ? Theme.red
                         : card.modelData.urgency === NotificationUrgency.Low ? Theme.fgDim
                         : Theme.accent
                }

                RowLayout {
                    id: body
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    anchors.leftMargin: 15
                    spacing: 12

                    // IconImage (not Image): resolves image://icon URLs through the icon theme
                    // without painting Qt's checkerboard placeholder for unknown names
                    IconImage {
                        visible: card.hasImage && status === Image.Ready
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignTop
                        implicitSize: 40
                        source: card.iconSource
                        asynchronous: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.summary !== "" ? card.modelData.summary : card.modelData.appName
                                color: Theme.fgBright
                                font.family: "monospace"
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: card.modelData.summary !== "" && card.modelData.appName !== ""
                                text: card.modelData.appName
                                color: Theme.fgDim
                                font.family: "monospace"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.maximumWidth: 120
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: card.modelData.body
                            color: Theme.fg
                            font.family: "monospace"
                            font.pixelSize: 12
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 6
                            elide: Text.ElideRight
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }

                        // Action buttons (skip "default": that's the click-on-body action)
                        Flow {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 6
                            visible: actionRepeater.count > 0

                            Repeater {
                                id: actionRepeater
                                model: card.modelData.actions.filter(a => a.identifier !== "default")

                                delegate: Rectangle {
                                    required property NotificationAction modelData
                                    implicitWidth: actionLabel.implicitWidth + 16
                                    implicitHeight: actionLabel.implicitHeight + 8
                                    color: actionHover.hovered ? Theme.muted : "transparent"
                                    border.width: 1
                                    border.color: Theme.muted

                                    Text {
                                        id: actionLabel
                                        anchors.centerIn: parent
                                        text: parent.modelData.text
                                        color: Theme.accent
                                        font.family: "monospace"
                                        font.pixelSize: 11
                                    }

                                    HoverHandler { id: actionHover }
                                    TapHandler { onTapped: parent.modelData.invoke() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
