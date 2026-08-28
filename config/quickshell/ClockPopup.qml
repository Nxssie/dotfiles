import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root
    property var anchorWindow

    signal dismissed()

    anchor.window: anchorWindow
    anchor.rect.x: anchorWindow ? anchorWindow.width / 2 - width / 2 : 0
    anchor.rect.y: anchorWindow ? anchorWindow.height : 0
    implicitWidth: 244
    implicitHeight: 280
    color: Theme.surface
    grabFocus: true

    onVisibleChanged: if (!root.visible) root.dismissed()

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    function shiftMonth(delta) {
        let m = viewMonth + delta
        let y = viewYear
        if (m < 0) { m = 11; y -= 1 }
        else if (m > 11) { m = 0; y += 1 }
        viewMonth = m
        viewYear = y
    }

    function buildCells(year, month) {
        const first = new Date(year, month, 1)
        const offset = (first.getDay() + 6) % 7 // Monday-first week
        const daysInMonth = new Date(year, month + 1, 0).getDate()
        const daysInPrev = new Date(year, month, 0).getDate()
        const today = new Date()
        const cells = []
        for (let i = 0; i < 42; i++) {
            let day, inMonth
            if (i < offset) {
                day = daysInPrev - offset + 1 + i
                inMonth = false
            } else if (i - offset < daysInMonth) {
                day = i - offset + 1
                inMonth = true
            } else {
                day = i - offset - daysInMonth + 1
                inMonth = false
            }
            const isToday = inMonth && year === today.getFullYear()
                && month === today.getMonth() && day === today.getDate()
            cells.push({ day: day, inMonth: inMonth, isToday: isToday })
        }
        return cells
    }

    property var cells: buildCells(viewYear, viewMonth)

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            width: parent.width

            Text {
                text: "" // nf-fa-chevron_left
                font.family: "Symbols Nerd Font"
                font.pixelSize: 12
                color: Theme.fg

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shiftMonth(-1)
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
                color: Theme.fgBright
                font.family: "monospace"
                font.pixelSize: 12
                font.bold: true
            }

            Text {
                text: "" // nf-fa-chevron_right
                font.family: "Symbols Nerd Font"
                font.pixelSize: 12
                color: Theme.fg

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shiftMonth(1)
                }
            }
        }

        Grid {
            width: parent.width
            columns: 7
            columnSpacing: 2

            Repeater {
                model: 7
                delegate: Text {
                    required property int index
                    width: (parent.width - 12) / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName(index + 1, Locale.ShortFormat)
                    color: Theme.fgDim
                    font.family: "monospace"
                    font.pixelSize: 10
                }
            }
        }

        Grid {
            width: parent.width
            columns: 7
            rowSpacing: 4
            columnSpacing: 2

            Repeater {
                model: root.cells
                delegate: Rectangle {
                    required property var modelData
                    width: (parent.width - 12) / 7
                    height: width
                    radius: 0
                    color: modelData.isToday ? Theme.accent : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.day
                        color: modelData.isToday ? Theme.surface : (modelData.inMonth ? Theme.fg : Theme.fgDim)
                        font.family: "monospace"
                        font.pixelSize: 11
                        font.bold: modelData.isToday
                    }
                }
            }
        }
    }
}
