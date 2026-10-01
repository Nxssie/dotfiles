import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid

// Replaces org.kde.plasma.digitalclock: its popup is compiled into the plugin and
// sizes itself to ~570x460 logical px, which cannot be configured. This one keeps
// the old quickshell clock popup: a compact, locale-aware month grid.
PlasmoidItem {
    id: root

    property date now: new Date()
    // Month shown in the popup; reset to the current one every time it opens
    property int viewYear: now.getFullYear()
    property int viewMonth: now.getMonth()

    readonly property int firstDay: Qt.locale().firstDayOfWeek // 0 = Sunday ... 6 = Saturday
    readonly property real cellSize: Kirigami.Units.gridUnit * 2

    function shiftMonth(delta) {
        const d = new Date(viewYear, viewMonth + delta, 1)
        viewYear = d.getFullYear()
        viewMonth = d.getMonth()
    }

    function showToday() {
        viewYear = now.getFullYear()
        viewMonth = now.getMonth()
    }

    // 6 weeks x 7 days, starting on the locale's first day of the week
    function buildCells(year, month, today) {
        const first = new Date(year, month, 1)
        const offset = (first.getDay() - firstDay + 7) % 7
        const cells = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(year, month, 1 - offset + i)
            cells.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month,
                isToday: d.getFullYear() === today.getFullYear()
                    && d.getMonth() === today.getMonth()
                    && d.getDate() === today.getDate()
            })
        }
        return cells
    }

    readonly property var cells: buildCells(viewYear, viewMonth, now)

    onExpandedChanged: if (expanded) showToday()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    toolTipMainText: Qt.formatDate(now, "dddd, d MMMM yyyy")
    toolTipSubText: ""

    // ---- Panel: "Thu 01 Oct  10:39:16" ----------------------------------------------
    compactRepresentation: MouseArea {
        Layout.minimumWidth: label.implicitWidth + Kirigami.Units.largeSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded

        PlasmaComponents3.Label {
            id: label
            anchors.centerIn: parent
            text: Qt.formatDateTime(root.now, "ddd dd MMM  HH:mm:ss")
            font.family: "monospace"
        }
    }

    // ---- Popup: month grid --------------------------------------------------------
    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: root.cellSize * 7 + Kirigami.Units.largeSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents3.ToolButton {
                icon.name: "go-previous"
                onClicked: root.shiftMonth(-1)
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.bold: true
                text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showToday()
                }
            }
            PlasmaComponents3.ToolButton {
                icon.name: "go-next"
                onClicked: root.shiftMonth(1)
            }
        }

        Grid {
            Layout.alignment: Qt.AlignHCenter
            columns: 7

            Repeater {
                model: 7
                PlasmaComponents3.Label {
                    required property int index
                    width: root.cellSize
                    horizontalAlignment: Text.AlignHCenter
                    opacity: 0.6
                    font: Kirigami.Theme.smallFont
                    text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.ShortFormat)
                }
            }

            Repeater {
                model: root.cells

                Rectangle {
                    required property var modelData
                    width: root.cellSize
                    height: root.cellSize * 0.8
                    radius: Kirigami.Units.cornerRadius
                    color: modelData.isToday ? Kirigami.Theme.highlightColor : "transparent"

                    PlasmaComponents3.Label {
                        anchors.centerIn: parent
                        text: modelData.day
                        opacity: modelData.inMonth ? 1 : 0.35
                        color: modelData.isToday ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                        font.bold: modelData.isToday
                    }
                }
            }
        }
    }
}
